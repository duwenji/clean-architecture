# 03. リスコフの置換原則 (LSP) - Liskov Substitution Principle

> **原則**: サブタイプはスーパータイプと置き換え可能であるべき。派生クラスがベースクラスのインターフェースを破ってはいけない。

## 🎯 コンセプト

```
インターフェース PaymentMethod がある
  ↓
CreditCardPayment, PayPalPayment など
複数の実装がある
  ↓
どの実装を使っても同じ結果が得られるべき
  ↓
「PaymentMethod を使う側」は
実装の違いを意識する必要がない
```

---

## ❌ LSPに違反する例

### シナリオ：矩形と正方形

```typescript
// ❌ 悪い例：正方形が矩形の契約を破っている

class Rectangle {
  protected width: number;
  protected height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }

  setWidth(width: number): void {
    this.width = width;
  }

  setHeight(height: number): void {
    this.height = height;
  }

  getArea(): number {
    return this.width * this.height;
  }
}

// 正方形は矩形の特殊ケース
class Square extends Rectangle {
  setWidth(width: number): void {
    // ❌ 正方形は幅と高さが常に同じ
    // つまり幅だけ変えると矩形の契約を破る
    this.width = width;
    this.height = width;  // 互いに依存している
  }

  setHeight(height: number): void {
    // ❌ 
    this.width = height;
    this.height = height;
  }
}

// クライアント側
function printArea(rectangle: Rectangle) {
  rectangle.setWidth(5);
  rectangle.setHeight(10);
  const area = rectangle.getArea();
  console.log(`Area: ${area}`);  // 期待値: 50
}

// 使用
const square = new Square(10, 10);
printArea(square);  // ❌ 出力: 100（期待値：50）
// 矩形のコントラクトが破られている
```

**問題:**
- 🔴 Square は Rectangle と置き換え不可能
- 🔴 クライアント側で型チェックが必要
- 🔴 予期しない動作をする

---

### シナリオ2：鳥の飛行

```typescript
// ❌ 悪い例：全ての鳥が飛べると仮定

interface Bird {
  fly(): void;
  eat(): void;
}

class Sparrow implements Bird {
  fly(): void {
    console.log('Sparrow flying');
  }
  eat(): void {
    console.log('Sparrow eating');
  }
}

class Penguin implements Bird {
  fly(): void {
    // ❌ ペンギンは飛べない
    throw new Error('Penguins cannot fly!');
  }
  eat(): void {
    console.log('Penguin eating');
  }
}

// クライアント側
function makeBirdFly(bird: Bird) {
  bird.fly();  // ❌ ペンギンを渡すと実行時エラー
}

const birds: Bird[] = [new Sparrow(), new Penguin()];
birds.forEach(bird => makeBirdFly(bird));  // エラーで落ちる
```

**問題:**
- 🔴 実装時にはエラーが出ない（コンパイルエラーなし）
- 🔴 実行時まで問題が発覚しない
- 🔴 クライアント側で各バリエーションをチェックする必要

---

## ✅ LSP を適用した設計

### 解決1：矩形と正方形の問題

```typescript
// ##### 適切な設計：矩形と正方形を分離 #####

// 共通インターフェース
export interface Shape {
  getArea(): number;
}

// 矩形（幅と高さが独立）
export class Rectangle implements Shape {
  constructor(
    private width: number,
    private height: number
  ) {}

  getArea(): number {
    return this.width * this.height;
  }

  // 幅と高さを独立して設定できる
  setDimensions(width: number, height: number): Rectangle {
    return new Rectangle(width, height);
  }
}

// 正方形（幅と高さが常に同じ）
export class Square implements Shape {
  constructor(private side: number) {}

  getArea(): number {
    return this.side * this.side;
  }

  // 辺の長さを設定
  setSide(side: number): Square {
    return new Square(side);
  }
}

// クライアント側
function calculateArea(shape: Shape): number {
  return shape.getArea();
}

// ✅ どちらを渡してもコントラクトを守る
const rect = new Rectangle(5, 10);
console.log(calculateArea(rect));  // 50

const square = new Square(7);
console.log(calculateArea(square));  // 49
```

### 解決2：鳥の飛行の問題

```typescript
// ##### 適切な設計：鳥を分類 #####

// 共通インターフェース：全ての鳥が持つ能力
export interface Bird {
  eat(): void;
  sleep(): void;
}

// 飛べる鳥用インターフェース
export interface FlyingBird extends Bird {
  fly(): void;
}

// 飛べない鳥用インターフェース
export interface SwimmingBird extends Bird {
  swim(): void;
}

// 実装：スズメ（飛べる）
export class Sparrow implements FlyingBird {
  eat(): void {
    console.log('Sparrow eating');
  }

  sleep(): void {
    console.log('Sparrow sleeping');
  }

  fly(): void {
    console.log('Sparrow flying');
  }
}

// 実装：ペンギン（泳げる、飛べない）
export class Penguin implements SwimmingBird {
  eat(): void {
    console.log('Penguin eating');
  }

  sleep(): void {
    console.log('Penguin sleeping');
  }

  swim(): void {
    console.log('Penguin swimming');
  }
}

// クライアント側
function makeBirdFly(bird: FlyingBird) {
  bird.fly();  // ✅ FlyingBirdのみを受け付ける
}

function makeBirdSwim(bird: SwimmingBird) {
  bird.swim();  // ✅ SwimmingBirdのみを受け付ける
}

// 使用
makeBirdFly(new Sparrow());  // ✅ OK
makeBirdFly(new Penguin());  // ❌ コンパイルエラー（事前に検出）

makeBirdSwim(new Penguin());  // ✅ OK
makeBirdSwim(new Sparrow());  // ❌ コンパイルエラー
```

---

## 📊 LSP 違反のパターン

### パターン1: 例外をスロー

```typescript
// ❌ LSP違反
interface PaymentMethod {
  process(amount: number): Promise<PaymentResult>;
}

class MockPaymentMethod implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    throw new Error('This is a mock method');  // ❌
  }
}

// ✅ LSP準拠
class MockPaymentMethod implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    return {
      success: true,
      transactionId: 'mock-tx-123',
      amount,
      timestamp: new Date()
    };
  }
}
```

### パターン2: 事前条件を厳しくする

```typescript
// ❌ LSP違反
class Database {
  query(sql: string): Promise<any> {
    // SQLスタートメント以上を処理できる
  }
}

class RestrictedDatabase extends Database {
  async query(sql: string): Promise<any> {
    // ❌ 事前条件を厳しくしている
    if (!sql.startsWith('SELECT')) {
      throw new Error('Only SELECT allowed');
    }
    return super.query(sql);
  }
}
```

### パターン3: 事後条件を弱くする

```typescript
// ❌ LSP違反
interface SavingsAccount {
  deposit(amount: number): void;
  withdraw(amount: number): void;  // 残高より多く引き出せない
  getBalance(): number;
}

class LoanAccount implements SavingsAccount {
  async withdraw(amount: number): void {
    // ❌ 事後条件を弱くしている
    // 残高以上でも引き出せる（負債になる）
    this.balance -= amount;
  }
}
```

---

## 🧪 テストで LSP を検証

```typescript
// LSP 違反をテストで検出
describe('Shape implementations', () => {
  function testShape(shape: Shape) {
    const area1 = shape.getArea();
    const area2 = shape.getArea();
    
    // ✅ 同じ結果が返される（メンタルモデルの一貫性）
    expect(area1).toBe(area2);
  }

  test('Rectangle substitution', () => {
    testShape(new Rectangle(5, 10));
  });

  test('Square substitution', () => {
    testShape(new Square(7));
  });
});

// LSP準拠のユースケーステスト
describe('PaymentProcessor LSP compliance', () => {
  async function testPaymentMethod(method: PaymentMethod) {
    const processor = new PaymentProcessor();
    const result = await processor.process(100, method);
    
    // ✅ 全ての実装が同じコントラクトを守っている
    expect(result).toHaveProperty('success');
    expect(result).toHaveProperty('transactionId');
    expect(result).toHaveProperty('amount');
    expect(result.amount).toBe(100);
  }

  test('CreditCard substitution', () => {
    return testPaymentMethod(new CreditCardPayment(...));
  });

  test('PayPal substitution', () => {
    return testPaymentMethod(new PayPalPayment(...));
  });

  test('BankTransfer substitution', () => {
    return testPaymentMethod(new BankTransferPayment(...));
  });
});
```

---

## 🎯 LSP チェックリスト

```
✅ 派生クラスが例外をスローしていないか
✅ 事前条件を厳しくしていないか
✅ 事後条件を弱くしていないか
✅ 契約不変条件を守っているか
✅ どの実装を代入しても挙動が予測可能か
```

---

## 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 入れ替え可能性の保証 |
| **チェック方法** | 派生クラスでコントラクト破っていないか |
| **メリット** | 予期しない動作の防止 |
| **キー** | インターフェースの契約を守る |

---

## ➡️ 次のステップ

次は、クライアントが必要のないメソッドに依存してはいけない、という **インターフェース分離の原則** を学びます。

[次: インターフェース分離の原則 →](./04-interface-segregation.md)
