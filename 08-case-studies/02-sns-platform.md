# 02: SNS プラットフォーム（フィード生成・キャッシング）

高スループット、リアルタイムフィード、大量のユーザーを扱うSNS。重点：スケーラビリティとキャッシング。

---

## 🎯 背景

ユーザーが投稿を作成・かんて、フォロワーのタイムラインにフィードが表示されるSNS。

**物になす必要な機能：**
- 投稿作成・削除
- いいね・コメント
- フォロー・フォロー解除
- パーソナライズされたフィード生成
- キャッシング・最適化
- リアルタイム通知

---

## 🏗️ ドメイン層

### エンティティ設計

```typescript
// domain/entities/Post.ts
export class Post {
  constructor(
    public id: string,
    public authorId: string,
    public content: PostContent,
    public likeCount: number = 0,
    public commentCount: number = 0,
    public createdAt: Date = new Date()
  ) {}

  // ビジネスロジック
  like(): void {
    this.likeCount++;
  }

  unlike(): void {
    if (this.likeCount > 0) {
      this.likeCount--;
    }
  }

  addComment(): void {
    this.commentCount++;
  }

  removeComment(): void {
    if (this.commentCount > 0) {
      this.commentCount--;
    }
  }

  isLikedBy(userId: string): boolean {
    // リポジトリから取得するのではなく、
    // Application層から渡された情報で判定
    // （パフォーマンスのため）
    return false;  // 実装は Application層で
  }
}

// domain/value-objects/PostContent.ts
export class PostContent {
  constructor(public text: string) {
    if (!text || text.length === 0) {
      throw new InvalidPostContentError('Content cannot be empty');
    }
    if (text.length > 280) {
      throw new InvalidPostContentError('Content must be 280 characters or less');
    }
  }

  getText(): string {
    return this.text;
  }
}

// domain/entities/User.ts（フォロー関連）
export class User {
  private followingIds: Set<string> = new Set();
  private followerIds: Set<string> = new Set();

  constructor(
    public id: string,
    public username: string,
    public email: Email
  ) {}

  follow(userId: string): void {
    if (userId === this.id) {
      throw new CannotFollowYourselfError();
    }
    this.followingIds.add(userId);
  }

  unfollow(userId: string): void {
    this.followingIds.delete(userId);
  }

  isFollowing(userId: string): boolean {
    return this.followingIds.has(userId);
  }

  getFollowingCount(): number {
    return this.followingIds.size;
  }

  getFollowerCount(): number {
    return this.followerIds.size;
  }
}

// domain/services/FeedService.ts（ドメインサービス）
export class FeedService {
  // フィード生成ロジック（複雑なビジネスルール）
  generateFeed(posts: Post[], userPreferences: UserPreferences): Post[] {
    return posts
      .filter(post => this.matchesUserInterests(post, userPreferences))
      .sort((a, b) => {
        // 新順（最新がトップ）
        const dateCompare = b.createdAt.getTime() - a.createdAt.getTime();
        if (dateCompare !== 0) return dateCompare;

        // 日時が同じ場合はいいね数でソート
        return b.likeCount - a.likeCount;
      })
      .slice(0, 50);
  }

  private matchesUserInterests(post: Post, prefs: UserPreferences): boolean {
    // ビジネスルール：フォローしているユーザーの投稿
    return prefs.followingUserIds.includes(post.authorId) ||
           prefs.interests.some(interest => post.content.getText().includes(interest));
  }

  // トレンド判定
  isTrending(post: Post): boolean {
    return post.likeCount > 100 && this.isRecent(post);
  }

  private isRecent(post: Post): boolean {
    const oneDayMs = 24 * 60 * 60 * 1000;
    return Date.now() - post.createdAt.getTime() < oneDayMs;
  }
}
```

---

## 💼 アプリケーション層

### フィード取得ユースケース（キャッシング統合）

```typescript
// application/usecases/GetUserFeedUseCase.ts
export class GetUserFeedUseCase {
  constructor(
    private postRepository: PostRepository,
    private feedService: FeedService,
    private cacheService: CacheService,
    private userRepository: UserRepository
  ) {}

  async execute(
    userId: string,
    params: { page: number; limit: number } = { page: 1, limit: 20 }
  ): Promise<PostDTO[]> {
    // キャッシュキーを生成
    const cacheKey = `feed:${userId}:${params.page}:${params.limit}`;

    // キャッシュから取得を試みる
    const cached = await this.cacheService.get<PostDTO[]>(cacheKey);
    if (cached) {
      logger.debug('Cache hit', { cacheKey });
      return cached;
    }

    logger.debug('Cache miss', { cacheKey });

    // ユーザーの基本情報と設定を取得
    const user = await this.userRepository.getById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }

    const userPrefs = await this.getUserPreferences(userId);

    // ページングで投稿を取得
    const posts = await this.postRepository.findByUserIds(
      Array.from(userPrefs.followingUserIds),
      {
        offset: (params.page - 1) * params.limit,
        limit: params.limit * 2  // バッファを持たせる
      }
    );

    // ドメインサービスでフィード生成
    const feedPosts = this.feedService.generateFeed(posts, userPrefs);
    const dtos = feedPosts
      .slice(0, params.limit)
      .map(post => this.postToDTO(post, userId));

    // キャッシュに保存（60秒）
    await this.cacheService.set(cacheKey, dtos, 60);

    return dtos;
  }

  private async getUserPreferences(userId: string): Promise<UserPreferences> {
    // キャッシュキー
    const prefsCacheKey = `user:prefs:${userId}`;

    // キャッシュから取得
    const cached = await this.cacheService.get<UserPreferences>(prefsCacheKey);
    if (cached) {
      return cached;
    }

    // キャッシュミス → DB から取得
    const preferences = await this.userRepository.getPreferences(userId);

    // キャッシュに保存（24時間）
    await this.cacheService.set(prefsCacheKey, preferences, 86400);

    return preferences;
  }

  private postToDTO(post: Post, userId: string): PostDTO {
    return {
      id: post.id,
      authorId: post.authorId,
      content: post.content.getText(),
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      createdAt: post.createdAt,
      isLikedByUser: false  // 別途クエリで取得
    };
  }
}

// application/usecases/CreatePostUseCase.ts
export class CreatePostUseCase {
  constructor(
    private postRepository: PostRepository,
    private cacheService: CacheService,
    private notificationService: NotificationService
  ) {}

  async execute(request: CreatePostRequest): Promise<PostDTO> {
    // 投稿を作成
    const post = new Post(
      uuid(),
      request.userId,
      new PostContent(request.content)
    );

    // DB に保存
    await this.postRepository.save(post);

    // フォロワーのフィードキャッシュを無効化
    const followers = await this.getFollowers(request.userId);
    
    for (const followerId of followers) {
      // そのユーザーのフィードキャッシュを全ページ削除
      await this.invalidateFeedCache(followerId);
    }

    // フォロワーに通知（非同期）
    this.notificationService.notifyFollowers(post);

    return {
      id: post.id,
      authorId: post.authorId,
      content: post.content.getText(),
      likeCount: 0,
      commentCount: 0,
      createdAt: post.createdAt,
      isLikedByUser: false
    };
  }

  private async invalidateFeedCache(userId: string): Promise<void> {
    // ユーザーのすべてのフィードページを無効化
    const pattern = `feed:${userId}:*`;
    await this.cacheService.deleteByPattern(pattern);
  }

  private async getFollowers(userId: string): Promise<string[]> {
    // `followers:${userId}` で保存されている配列を取得
    return await this.cacheService.get(`followers:${userId}`) || [];
  }
}
```

---

## 🗄️ インフラ層

### レイヤー化されたキャッシング戦略

```typescript
// infrastructure/repositories/RedisPostRepository.ts
export class RedisPostRepository implements PostRepository {
  constructor(
    private redis: Redis,
    private mysql: Pool
  ) {}

  async save(post: Post): Promise<void> {
    // 両方に書き込み
    await Promise.all([
      // MySQL
      this.mysql.query(
        `INSERT INTO posts (id, author_id, content, created_at) 
         VALUES (?, ?, ?, NOW())`,
        [post.id, post.authorId, post.content.getText()]
      ),

      // Redis キャッシュ（1時間）
      this.redis.setex(
        `post:${post.id}`,
        3600,
        JSON.stringify({
          id: post.id,
          authorId: post.authorId,
          content: post.content.getText(),
          likeCount: post.likeCount,
          commentCount: post.commentCount,
          createdAt: post.createdAt
        })
      )
    ]);

    // 最新投稿リストに追加
    await this.redis.lpush(`posts:latest`, post.id);
    await this.redis.ltrim(`posts:latest`, 0, 1000);  // 最新1000件を保持
  }

  async getById(id: string): Promise<Post | null> {
    // Redis から優先的に取得
    const cached = await this.redis.get(`post:${id}`);

    if (cached) {
      logger.debug('Post cache hit', { postId: id });
      const data = JSON.parse(cached);
      return this.reconstructPost(data);
    }

    logger.debug('Post cache miss', { postId: id });

    // MySQL から取得
    const [rows] = await this.mysql.query(
      'SELECT * FROM posts WHERE id = ?',
      [id]
    );

    if (!rows.length) {
      return null;
    }

    const post = this.reconstructPost(rows[0]);

    // キャッシュに保存
    await this.redis.setex(`post:${id}`, 3600, JSON.stringify(rows[0]));

    return post;
  }

  async findByUserIds(
    userIds: string[],
    pagination: { offset: number; limit: number }
  ): Promise<Post[]> {
    // N+1を避けるため、複数ユーザーの投稿を一度に取得
    const [rows] = await this.mysql.query(
      `SELECT * FROM posts 
       WHERE author_id IN (?)
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [userIds, pagination.limit, pagination.offset]
    );

    return rows.map(row => this.reconstructPost(row));
  }

  private reconstructPost(data: any): Post {
    return new Post(
      data.id,
      data.author_id,
      new PostContent(data.content),
      data.like_count || 0,
      data.comment_count || 0,
      new Date(data.created_at)
    );
  }
}

// infrastructure/cache/RedisLikeCache.ts（いいね情報キャッシング）
export class RedisLikeCache {
  constructor(private redis: Redis) {}

  async addLike(postId: string, userId: string): Promise<void> {
    // `post:${postId}:likes` に user ID をセットで保存
    await this.redis.sadd(`post:${postId}:likes`, userId);
    
    // ユーザーが いいねした投稿リスト
    await this.redis.sadd(`user:${userId}:liked-posts`, postId);

    // TTL: 24時間
    await this.redis.expire(`post:${postId}:likes`, 86400);
  }

  async removeLike(postId: string, userId: string): Promise<void> {
    await Promise.all([
      this.redis.srem(`post:${postId}:likes`, userId),
      this.redis.srem(`user:${userId}:liked-posts`, postId)
    ]);
  }

  async getLikeCount(postId: string): Promise<number> {
    return await this.redis.scard(`post:${postId}:likes`);
  }

  async isLikedBy(postId: string, userId: string): Promise<boolean> {
    return await this.redis.sismember(`post:${postId}:likes`, userId) === 1;
  }
}
```

---

## 📊 キャッシング戦略

| キャッシュ対象 | 保存先 | TTL | インバリデータ時期 |
|------------|-------|-----|-----------------|
| ユーザープロフィール | Redis | 24時間 | プロフィール更新時 |
| フィード | Redis | 60秒 | 新投稿作成時 |
| 個別投稿 | Redis | 3600秒 | 削除/編集時 |
| いいね情報 | Redis Set | 86400秒 | いいね追加/削除時 |
| フォロー情報 | Redis Set | 永続 | フォロー変更時 |

---

## 🎯 重要な設計ポイント

### 1. キャッシュインバリデータ戦略

キャッシュを無効化する時期を明確に：
- 投稿作成 → フォロワーのフィードキャッシュ削除
- フォロー追加 → ユーザーのフィードキャッシュ削除
- いいね → フィード再計算が必要か判定

### 2. キャッシュ一貫性

MySQL と Redis が乖離しないよう、更新時は両方を更新。

### 3. 大量データの効率的な取得

フォロワー一覧、フォロー中の投稿リストは Redis のセット構造を活用。

---

## 📋 チェックリスト

```
キャッシング戦略
✅ キャッシュキーの命名が一貫
✅ TTL が適切（リアルタイム性 vs キャッシュ効率）
✅ インバリデータ戦略がある
✅ キャッシュミス時のDB負荷が考慮

パフォーマンス
✅ N+1 が存在しない
✅ パジングが実装されている
✅ 大量データのソート・フィルタリングが効率的

ドメイン設計
✅ ビジネスロジックが Entity/Service に
✅ Cache層 にはロジックなし
```

---

**次: [マイクロサービス →](./03-microservices.md)**
