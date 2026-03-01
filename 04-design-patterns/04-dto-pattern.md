# 04. DTO パターン (Data Transfer Object)

> **パターン**: 層間でのデータ転送用オブジェクト。ドメインモデルと外部表現を分離。

## 🎯 コンセプト

```
プレゼンテーション層 ← DTO → アプリケーション層 ← ドメイン層

ドメインモデルを直接公開しない
```

---

## 💻 実装例

### Request DTO

```typescript
// presentation/dto/request/CreateUserRequest.ts
export interface CreateUserRequest {
  email: string;
  password: string;
  name: string;
}

// バリデーション
export class CreateUserRequestValidator {
  validate(data: any): CreateUserRequest {
    if (!data.email || !data.password || !data.name) {
      throw new ValidationError('Missing required fields');
    }
    return data;
  }
}
```

### Response DTO

```typescript
// presentation/dto/response/UserResponse.ts
export interface UserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: string;  // ISO形式
}

// ドメインモデルから DTO に変換
export class UserMapper {
  toUserResponse(user: User): UserResponse {
    return {
      id: user.getId(),
      email: user.getEmail().getValue(),
      name: user.getName(),
      createdAt: user.getCreatedAt().toISOString()
    };
  }

  // Request DTO - ドメインモデル
  toDomainUser(request: CreateUserRequest): User {
    return new User(
      uuid(),
      new Email(request.email),
      new HashedPassword(request.password),
      request.name
    );
  }
}
```

### Application DTO

```typescript
// application/dto/RegisterUserDTO.ts
export interface RegisterUserDTO {
  email: string;
  password: string;
  name: string;
}

export interface RegisterUserResponseDTO {
  userId: string;
  email: string;
  createdAt: Date;
}
```

---

## 📊 層間のデータフロー

```
1. HTTP Request
   ↓
2. Presentation DTO (CreateUserRequest)
   ↓ バリデーション・マッピング
3. Application DTO (RegisterUserDTO)
   ↓ ドメイン層へ
4. Domain (User Entity)
   ↓ 処理後
5. Application DTO (RegisterUserResponseDTO)
   ↓ マッピング
6. Presentation DTO (UserResponse)
   ↓
7. HTTP Response
```

---

## 🧪 テスト

```typescript
describe('UserMapper', () => {
  test('should map user to response', () => {
    const user = new User('1', new Email('test@example.com'), new HashedPassword('hashed'), 'John');
    const mapper = new UserMapper();

    const response = mapper.toUserResponse(user);

    expect(response.email).toBe('test@example.com');
    expect(response.name).toBe('John');
  });

  test('should validate request DTO', () => {
    const validator = new CreateUserRequestValidator();

    expect(() => {
      validator.validate({ email: 'test@example.com', password: 'pass' });
    }).toThrow(ValidationError);
  });
});
```

---

## 📋 チェックリスト

```
✅ ドメインモデルが公開されていない
✅ 層ごとに独立した DTO 定義
✅ マッピング責任が明確
✅ バリデーションが適切な層で実施
```

---

[次: アダプタパターン →](./05-adapter-pattern.md)
