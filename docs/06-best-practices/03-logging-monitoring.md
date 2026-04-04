# 03: ロギング・監視

本番環境での問題調査・パフォーマンス監視を実現。

---

## 🎯 ロギング戦略

```
構造化ログ：機械可読
│
段階的：レベル別分類
│
文脈：コンテキスト情報含む
```

---

## 📊 ログレベル別使い分け

```typescript
logger.info('User registration request', { email, ip: req.ip });
logger.debug('Creating new user', { email, userId });
logger.warn('Retry attempt 2/3', { endpoint, error });
logger.error('Database query failed', { query, error });
logger.fatal('System shutdown initiated', { reason });
```

| レベル | 出力先 | 用途 |
|-------|-------|------|
| `debug` | ファイル | 開発・トラブルシューティング |
| `info` | ファイル | 正常な処理の進行状況 |
| `warn` | ファイル+Alert | 異常だが処理可能 |
| `error` | ファイル+Alert | エラー発生 |
| `fatal` | ファイル+Alert | システム停止レベル |

---

## 🏗️ 階層別ロギング

### プレゼンテーション層：リクエスト/レスポンス

```typescript
// presentation/middlewares/LoggingMiddleware.ts
export const loggingMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  const { method, path, ip } = req;

  // リクエストログ
  logger.info('Incoming request', {
    method,
    path,
    ip,
    userId: req.user?.id,
    userAgent: req.get('user-agent')
  });

  // レスポンス後
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const { statusCode } = res;

    if (statusCode >= 400) {
      logger.warn('Request failed', {
        method,
        path,
        statusCode,
        duration
      });
    } else {
      logger.debug('Request completed', {
        method,
        path,
        statusCode,
        duration
      });
    }
  });

  next();
};
```

### アプリケーション層：ユースケース実行

```typescript
// application/usecases/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  async execute(request: RegisterUserRequest): Promise<void> {
    const startTime = Date.now();

    logger.debug('RegisterUserUseCase: starting', {
      email: request.email
    });

    try {
      const email = new Email(request.email);

      // ビジネスロジック
      const existing = await this.userRepository.findByEmail(email);
      if (existing) {
        logger.warn('User already exists', { email: request.email });
        throw new UserAlreadyExistsError();
      }

      const user = await User.create(email, request.password, request.name);
      await this.userRepository.save(user);

      logger.info('User registered successfully', {
        userId: user.getId(),
        email: request.email,
        duration: Date.now() - startTime
      });
    } catch (error) {
      logger.error('User registration failed', {
        email: request.email,
        error: error.message,
        duration: Date.now() - startTime
      });
      throw error;
    }
  }
}
```

### インフラ層：DB・API呼び出し

```typescript
// infrastructure/repositories/UserRepository.ts
export class UserRepository implements IUserRepository {
  async save(user: User): Promise<void> {
    const startTime = Date.now();

    try {
      logger.debug('Executing INSERT query', {
        table: 'users',
        userId: user.getId()
      });

      await this.db.query('INSERT INTO users ...', [user.getId(), ...]);

      logger.debug('User saved to database', {
        userId: user.getId(),
        duration: Date.now() - startTime
      });
    } catch (error) {
      logger.error('Database insert failed', {
        userId: user.getId(),
        error: error.message,
        duration: Date.now() - startTime
      });
      throw new DatabaseError('Failed to save user');
    }
  }
}

// infrastructure/adapters/EmailAdapter.ts
export class EmailAdapter implements IEmailSendingService {
  async send(to: string, subject: string, body: string): Promise<void> {
    const startTime = Date.now();

    try {
      logger.debug('Sending email', { to, subject });

      const response = await fetch('https://api.sendgrid.com/...', {
        method: 'POST',
        body: JSON.stringify({ to, subject, html: body })
      });

      if (!response.ok) {
        throw new Error(`SendGrid error: ${response.statusText}`);
      }

      logger.info('Email sent successfully', {
        to,
        subject,
        duration: Date.now() - startTime
      });
    } catch (error) {
      logger.error('Email sending failed', {
        to,
        subject,
        error: error.message,
        duration: Date.now() - startTime
      });
      // メール失敗はログするが、アプリケーションは続行
    }
  }
}
```

---

## 🔍 構造化ログの実装

### Winston (Node.js 推奨)

```typescript
// config/logger.ts
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'user-management' },
  transports: [
    // ファイルに出力
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),

    // 本番環境ではコンソール抑制
    ...(process.env.NODE_ENV !== 'production'
      ? [new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.printf(
              ({ timestamp, level, message, ...rest }) =>
                `${timestamp} [${level}] ${message} ${JSON.stringify(rest)}`
            )
          )
        })]
      : [])
  ]
});

export default logger;
```

### Console クラスで囲む

```typescript
// イメージ: console.log はログに含めない
console.log('Debug info');  // ❌ 本番環境で見えてしまう

// `logger` を使う
logger.debug('Debug info');  // ✅ ログレベル制御
```

---

## 📈 監視・メトリクス

### Prometheus メトリクス例

```typescript
// infrastructure/monitoring/PrometheusMetrics.ts
import { Counter, Histogram, register } from 'prom-client';

export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

export const userRegistrationCounter = new Counter({
  name: 'user_registration_total',
  help: 'Total number of user registrations',
  labelNames: ['status']
});

export const databaseQueryDuration = new Histogram({
  name: 'database_query_duration_seconds',
  help: 'Duration of database queries',
  labelNames: ['operation', 'table']
});

// 使用例
httpRequestDuration
  .labels('POST', '/users/register', '201')
  .observe(0.5);

userRegistrationCounter.labels('success').inc();
```

### アラート設定（Grafana）

```yaml
# Example alerting rule
alert: HighErrorRate
expr: |
  (
    sum(rate(http_request_total{status=~"5.."}[5m]))
    /
    sum(rate(http_request_total[5m]))
  ) > 0.05
for: 5m
annotations:
  summary: "High error rate detected"
  description: "Error rate is {{ $value | humanizePercentage }}"
```

---

## 🔐 ログのセキュリティ

```typescript
// ❌ 危険：センシティブ情報をログに含める
logger.info('User registered', {
  email: request.email,
  password: request.password,    // 絶対禁止
  creditCard: request.creditCard  // 絶対禁止
});

// ✅ 安全：ハッシュまたは省略
logger.info('User registered', {
  email: hashEmail(request.email),
  passwordLength: request.password.length,  // 長さだけ
  creditCardLast4: request.creditCard.slice(-4)
});

// ✅ 開発環境のみセンシティブ情報
if (process.env.NODE_ENV === 'development') {
  logger.debug('User data', { ...userData });
}
```

---

## 📋 チェックリスト

```
✅ ログレベルが適切に設定されている
✅ 構造化ログ（JSON形式）
✅ タイムスタンプを含める
✅ リクエスト ID でトレーシング可能
✅ センシティブ情報を除外
✅ ロテーション設定（ファイルサイズ制限）
✅ 中央ログ管理（ELK Stack など）
✅ アラート体制
```

---

**次: [パフォーマンス最適化 →](./04-performance-optimization.md)**
