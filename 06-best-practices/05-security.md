# 05: セキュリティ

入力検証、認証・認可、暗号化で堅牢なシステムを構築。

---

## 🎯 セキュリティの原則

```
深層防御：複数層でチェック
│
最小権限：必要最小限のアクセス
│
可視化：監視・ログで検出
```

---

## 🔐 入力検証（複数層）

### プレゼンテーション層：型・形式チェック

```typescript
// presentation/middlewares/ValidationMiddleware.ts
import { body, validationResult } from 'express-validator';

export const validateUserRegistration = [
  body('email')
    .isEmail()
    .normalizeEmail(),

  body('password')
    .isLength({ min: 8 })
    .withMessage('At least 8 characters'),

  body('name')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be 2-100 characters'),

  (req: Request, res: Response, next: NextFunction) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }
    next();
  }
];

// routes/userRoutes.ts
router.post('/register', validateUserRegistration, userController.register);
```

### ドメイン層：ビジネスルール検証

```typescript
// domain/value-objects/Email.ts
export class Email {
  private readonly value: string;

  constructor(value: string) {
    // より厳密なメール形式チェック
    if (!this.isValidEmail(value)) {
      throw new InvalidEmailError(`Invalid email: ${value}`);
    }

    // DNSチェック（本番環境）
    if (process.env.NODE_ENV === 'production') {
      this.validateDNS(value);
    }

    this.value = value.toLowerCase();
  }

  private isValidEmail(email: string): boolean {
    // RFC 5322
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  private validateDNS(email: string): void {
    // DNSレコード確認
    const domain = email.split('@')[1];
    // DNS lookup implementation
  }
}

// domain/value-objects/Password.ts
export class Password {
  static async fromPlainText(plainPassword: string): Promise<Password> {
    // 強度チェック
    this.validateStrength(plainPassword);

    // ハッシュ化
    const hashedValue = await bcrypt.hash(plainPassword, 12);
    return new Password(hashedValue);
  }

  private static validateStrength(password: string): void {
    const errors: string[] = [];

    if (password.length < 8) errors.push('8文字以上');
    if (!/[A-Z]/.test(password)) errors.push('大文字を含む');
    if (!/[a-z]/.test(password)) errors.push('小文字を含む');
    if (!/[0-9]/.test(password)) errors.push('数字を含む');
    if (!/[!@#$%^&*]/.test(password)) errors.push('特殊文字を含む');

    if (errors.length > 0) {
      throw new WeakPasswordError(`パスワードは以下を満たしてください: ${errors.join(', ')}`);
    }
  }
}
```

### インフラ層：DB スキーマ制約

```typescript
-- DDL
CREATE TABLE users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(100) NOT NULL,
  CHECK (LENGTH(password_hash) >= 60),  -- bcryptハッシュサイズ
  CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$')
);
```

---

## 🔑 Authentication/Authorization

### JWT ベース認証

```typescript
// infrastructure/services/JwtTokenGenerator.ts
import * as jwt from 'jsonwebtoken';

export class JwtTokenGenerator implements ITokenGenerator {
  private readonly secret = process.env.JWT_SECRET || 'your-secret-key';
  private readonly expiresIn = '24h';

  async generate(userId: string, role: string): Promise<string> {
    return jwt.sign(
      { userId, role },
      this.secret,
      { expiresIn: this.expiresIn }
    );
  }

  async verify(token: string): Promise<{ userId: string; role: string }> {
    try {
      return jwt.verify(token, this.secret) as { userId: string; role: string };
    } catch (error) {
      throw new UnauthorizedError('Invalid or expired token');
    }
  }
}

// presentation/middlewares/AuthenticationMiddleware.ts
export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid token' });
  }

  const token = authHeader.slice(7);  // "Bearer " を削除

  try {
    const decoded = tokenGenerator.verify(token);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized' });
  }
};
```

### Role-Based Access Control（RBAC）

```typescript
// presentation/middlewares/AuthorizationMiddleware.ts
export const authorize = (allowedRoles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Only ${allowedRoles.join(',')} can access this resource`
      });
    }

    next();
  };
};

// routes/userRoutes.ts
router.delete('/users/:id',
  authenticate,
  authorize(['admin']),
  userController.deleteUser
);
```

---

## 🛡️ SQL インジェクション対策

### ❌ 悪い例

```typescript
// 危険：文字列連結
const query = `SELECT * FROM users WHERE email = '${email}'`;
await db.query(query);

// 攻撃例
// email = "' OR '1'='1"
// → SELECT * FROM users WHERE email = '' OR '1'='1'  (全件取得)
```

### ✅ 良い例

```typescript
// パラメータライズドクエリ
const query = 'SELECT * FROM users WHERE email = ?';
await db.query(query, [email]);

// または名前付きパラメータ
const query = 'SELECT * FROM users WHERE email = :email';
await db.query(query, { email });
```

---

## 🔒 パスワード・機密情報

### bcrypt でハッシュ化

```typescript
// ❌ 悪い例
const hashedPassword = Buffer.from(password).toString('base64');

// ✅ 良い例
const hashedPassword = await bcrypt.hash(password, 12);

// 検証
const isMatch = await bcrypt.compare(plainPassword, hashedPassword);
```

### 機密情報の管理

```typescript
// .env（コミットしない）
DB_PASSWORD=secure_password
JWT_SECRET=your-secret-key
API_KEY=12345abcde

// config/secrets.ts
export const secrets = {
  dbPassword: process.env.DB_PASSWORD,
  jwtSecret: process.env.JWT_SECRET,
  apiKey: process.env.API_KEY
};

// ❌ ログに機密情報を含めない
logger.info('User data', { password: request.password });  // 危険

// ✅
logger.info('User registered', { email: request.email });
```

---

## 📤 CORS・ヘッダーセキュリティ

```typescript
// presentation/middlewares/SecurityHeadersMiddleware.ts
import cors from 'cors';
import helmet from 'helmet';

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Helmet でセキュリティヘッダー自動化
app.use(helmet());

// 手動設定例
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');      // MIME Type Sniffing 防止
  res.setHeader('X-Frame-Options', 'DENY');                // Clickjacking 防止
  res.setHeader('X-XSS-Protection', '1; mode=block');      // XSS 防止
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  next();
});
```

---

## 🚨 レート制限・DDoS対策

```typescript
// presentation/middlewares/RateLimitMiddleware.ts
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15分
  max: 100,                   // 100リクエスト
  message: 'Too many requests, please try again later'
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,  // ログインは厳しく制限
  skipSuccessfulRequests: true
});

app.post('/users/login', authLimiter, userController.login);
app.use(limiter);  // 他のエンドポイント
```

---

## 📋 セキュリティチェックリスト

```
入力検証
✅ 型チェック（プレゼンテーション層）
✅ ビジネスルール検証（ドメイン層）
✅ DB スキーマ制約

認証・認可
✅ JWT トークンベース認証
✅ トークン有効期限設定
✅ RBAC で権限管理
✅ ブルートフォース攻撃対策

パスワード
✅ bcrypt でハッシュ化
✅ Salt を使用
✅ 強度チェック

インジェクション対策
✅ パラメータライズドクエリ
✅ SQL エスケープ
✅ コマンドインジェクション対策

機密情報
✅ .env で環境変数管理
✅ センシティブ情報をログに出力しない
✅ HTTPS を強制

HTTP セキュリティ
✅ CORS 設定
✅ Security Headers
✅ HTTPS/TLS
✅ CSRF トークン

監視
✅ ログで不正アクセス検出
✅ レート制限
✅ WAF（Web Application Firewall）
```

---

## 🔗 関連セクション

- [エラーハンドリング](./02-error-handling.md) - エラーレスポンス
- [ロギング・監視](./03-logging-monitoring.md) - セキュリティイベント監視

---

**完了！ベストプラクティスマスター**
