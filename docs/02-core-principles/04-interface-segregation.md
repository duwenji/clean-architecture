# 04. インターフェース分離の原則 (ISP) - Interface Segregation Principle

> **原則**: クライアントは自分が使わないメソッドに依存してはいけない。大きなインターフェースは小さな専門的インターフェースに分割すべき。

## 🎯 コンセプト

```
大きなインターフェース
├─ メソッドA（使いたい）
├─ メソッドB（使いたい）
├─ メソッドC（使いたくない）
├─ メソッドD（使いたくない）
└─ メソッドE（使いたくない）

      ↓ 分割

小さな専門的インターフェース
├─ InterfaceX（メソッドA, B）
└─ InterfaceY（メソッドC, D, E）
```

---

## ❌ ISPに違反する例

### シナリオ：複数機能を持つWorkerインターフェース

```typescript
// ❌ 悪い例：大きすぎるインターフェース

interface Worker {
  work(): void;
  eat(): void;
  manage(): void;
  reportToHR(): void;
  approveLeave(): void;
  codereview(): void;
}

// マネージャー：全部実装できる
class Manager implements Worker {
  work(): void { console.log('Manager working'); }
  eat(): void { console.log('Manager eating'); }
  manage(): void { console.log('Manager managing'); }
  reportToHR(): void { console.log('Manager reports'); }
  approveLeave(): void { console.log('Manager approves'); }
  codereview(): void { console.log('Manager reviewing code'); }
}

// 一般的なエンジニア：全部実装しなければならない
class Engineer implements Worker {
  work(): void { console.log('Engineer working'); }
  eat(): void { console.log('Engineer eating'); }
  manage(): void { throw new Error('Engineer cannot manage'); }  // ❌
  reportToHR(): void { throw new Error('Engineer cannot report'); }  // ❌
  approveLeave(): void { throw new Error('Engineer cannot approve'); }  // ❌
  codereview(): void { console.log('Engineer reviewing code'); }
}

// インターン：使えないメソッドばかり
class Intern implements Worker {
  work(): void { console.log('Intern working'); }
  eat(): void { console.log('Intern eating'); }
  manage(): void { throw new Error('Intern cannot manage'); }  // ❌
  reportToHR(): void { throw new Error('Intern cannot report'); }  // ❌
  approveLeave(): void { throw new Error('Intern cannot approve'); }  // ❌
  codereview(): void { console.log('Intern learning code'); }
}
```

**問題:**
- 🔴 全員が全メソッド実装を強要される
- 🔴 使わないメソッドに依存させられる
- 🔴 例外スローが多発
- 🔴 型安全性がない
- 🔴 動作が予測できない

---

## ✅ ISP を適用した設計

### Step 1: 責任ごとインターフェースを分割

```typescript
// ##### 小さな専門的インターフェース #####

// 基本的な作業インターフェース
export interface Workable {
  work(): void;
  eat(): void;
}

// 管理機能のインターフェース
export interface Manageable {
  manage(): void;
  approveLeave(): void;
}

// HR報告のインターフェース
export interface HRReportable {
  reportToHR(): void;
}

// コードレビューのインターフェース
export interface Reviewable {
  codeReview(): void;
}
```

### Step 2: インターフェースを組み合わせて実装

```typescript
// ##### 実装：各役割に必要なインターフェースのみ #####

// マネージャー：複数インターフェース実装
export class Manager implements Workable, Manageable, HRReportable, Reviewable {
  work(): void {
    console.log('Manager working');
  }

  eat(): void {
    console.log('Manager eating');
  }

  manage(): void {
    console.log('Manager managing team');
  }

  approveLeave(): void {
    console.log('Manager approves leave');
  }

  reportToHR(): void {
    console.log('Manager reports to HR');
  }

  codeReview(): void {
    console.log('Manager reviewing code');
  }
}

// エンジニア：必要なインターフェースのみ実装
export class Engineer implements Workable, Reviewable {
  work(): void {
    console.log('Engineer working');
  }

  eat(): void {
    console.log('Engineer eating');
  }

  codeReview(): void {
    console.log('Engineer reviewing code');
  }

  // ✅ 不要なメソッドに依存しない
}

// インターン：必要最小限のインターフェース
export class Intern implements Workable {
  work(): void {
    console.log('Intern working');
  }

  eat(): void {
    console.log('Intern eating');
  }

  // ✅ 必要なメソッドだけ実装
}
```

### Step 3: クライアント側でも分割

```typescript
// ##### クライアント側でも適切なインターフェースのみ依存 #####

// 作業を割り当てるシステム
export class TaskAssigner {
  assignWork(worker: Workable): void {
    // ✅ Workable のみ必要
    worker.work();
  }
}

// レビュープロセス
export class CodeReviewProcess {
  requestReview(reviewer: Reviewable): void {
    // ✅ Reviewable のみ必要
    reviewer.codeReview();
  }
}

// 休暇承認システム
export class LeaveApprovalSystem {
  approveLeave(approver: Manageable): void {
    // ✅ Manageable のみ必要
    approver.approveLeave();
  }
}

// HR システム
export class HRSystem {
  receiveReport(reporter: HRReportable): void {
    // ✅ HRReportable のみ必要
    reporter.reportToHR();
  }
}
```

### Step 4: 実装例

```typescript
// 使用例
const manager = new Manager();
const engineer = new Engineer();
const intern = new Intern();

// TaskAssigner は全員を処理できる
const taskAssigner = new TaskAssigner();
taskAssigner.assignWork(manager);    // ✅
taskAssigner.assignWork(engineer);   // ✅
taskAssigner.assignWork(intern);     // ✅

// CodeReviewProcess は Reviewable を実装した人のみ
const reviewProcess = new CodeReviewProcess();
reviewProcess.requestReview(manager);    // ✅
reviewProcess.requestReview(engineer);   // ✅
reviewProcess.requestReview(intern);     // ❌ コンパイルエラー（正しい）

// LeaveApprovalSystem は Manageable を実装した人のみ
const leaveSystem = new LeaveApprovalSystem();
leaveSystem.approveLeave(manager);     // ✅
leaveSystem.approveLeave(engineer);    // ❌ コンパイルエラー（正しい）
leaveSystem.approveLeave(intern);      // ❌ コンパイルエラー（正しい）
```

---

## 📊 ISP違反のパターン

### パターン1: God インターフェース

```typescript
// ❌ ISP違反：疲れモジュール
interface Document {
  open(): void;
  close(): void;
  save(): void;
  print(): void;
  fax(): void;
  replicate(): void;
  bind(): void;
}

// すべてのドキュメント実装前に全部作成する必要がある
class PDFDocument implements Document {
  // ...
}

// すべてを実装する必要がある
class SimpleTextDocument implements Document {
  print(): void { console.log('Printing'); }
  fax(): void { throw new Error('Cannot fax text'); }  // ❌ 不要なメソッド
  // ...
}
```

### パターン2: 責務が混在

```typescript
// ❌ ISP違反
interface UserService {
  // ユーザー管理
  getUser(id: string): User;
  saveUser(user: User): void;

  // メール送信
  sendEmail(to: string, message: string): void;

  // ロギング
  logActivity(userId: string, action: string): void;

  // キャッシュ管理
  clearCache(): void;
}

// ✅ ISP準拠：責務ごとに分割
interface UserRepository {
  getUser(id: string): User;
  saveUser(user: User): void;
}

interface EmailService {
  sendEmail(to: string, message: string): void;
}

interface ActivityLogger {
  logActivity(userId: string, action: string): void;
}

interface CacheManager {
  clearCache(): void;
}
```

---

## 🧪 テスト

ISP を適用すると、テストが容易になります：

```typescript
describe('ISP - Interface Segregation', () => {
  // 個別にテスト可能
  describe('TaskAssigner', () => {
    test('should assign work to any Workable', () => {
      const mockWorker: Workable = {
        work: jest.fn(),
        eat: jest.fn()
      };

      const assigner = new TaskAssigner();
      assigner.assignWork(mockWorker);

      expect(mockWorker.work).toHaveBeenCalled();
    });
  });

  describe('CodeReviewProcess', () => {
    test('should request review from Reviewable', () => {
      const mockReviewer: Reviewable = {
        codeReview: jest.fn()
      };

      const process = new CodeReviewProcess();
      process.requestReview(mockReviewer);

      expect(mockReviewer.codeReview).toHaveBeenCalled();
    });
  });

  // モック作成が簡単（必要なメソッドだけ）
  describe('LeaveApprovalSystem', () => {
    test('should approve leave from Manageable', () => {
      const mockManager: Manageable = {
        manage: jest.fn(),
        approveLeave: jest.fn()
      };

      const system = new LeaveApprovalSystem();
      system.approveLeave(mockManager);

      expect(mockManager.approveLeave).toHaveBeenCalled();
    });
  });
});
```

---

## 🎯 ISP チェックリスト

```
✅ インターフェースに「実装する必要がないメソッド」がないか
✅ インターフェースが1つの責務を表現しているか
✅ インターフェース利用者が必要なメソッドだけ実装するか
✅ 小さなインターフェースの組み合わせで構成されているか
✅ モック作成が簡単か（必要なメソッドだけ）
```

---

## 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 不要な依存を避ける |
| **実装** | インターフェース分割 |
| **単位** | 責務 or 能力 |
| **メリット** | テスト容易、柔軟性 |
| **反対** | God インターフェース |

---

## ➡️ 次のステップ

最後の原則 **依存性逆転の原則** は、高レベルモジュールが低レベルモジュールに依存してはいけない、という最も重要な原則です。

[次: 依存性逆転の原則 →](./05-dependency-inversion.md)
