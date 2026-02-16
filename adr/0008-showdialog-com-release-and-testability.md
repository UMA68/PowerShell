# ADR-0008: ShowDialog の COM 解放とテスト容易性

## Status
Accepted

## Context
Test-ModuleInstalledのShowDialogパスでは、WScript.ShellのCOMオブジェクトを生成してPopupを表示し、finallyでCOM解放処理を行っている。

一方で、テストではUI表示を避けるためにNew-Objectをモックし、Popupの呼び出し回数とメッセージ内容を検証したい。

しかし、COMオブジェクト前提の解放処理やネイティブPopupの実装が混在すると、テストダブルによる検証が不安定になる。

## Decision
次の方針を採用する。

1. ShowDialogパスのCOM解放は `__ComObject` の場合に限定する  
2. テストではCOMの代わりに `PSCustomObject` を返す  
3. Popupをテストダブルに差し替え、呼び出し回数とメッセージ内容をUI非依存で検証する  

## Rationale
- COM解放処理を誤ると未定義動作につながる可能性がある  
- UI表示は自動テストと相性が悪く、隔離が必須である  
- テストダブルを前提とする設計を明文化することで、今後のCOM利用時に同じ判断を再現できる  

## Alternatives Considered
1. COM解放を従来どおり全オブジェクトに適用する  
   - 非COMに対する解放安全性が担保できない  
2. ShowDialogのUI表示を含む統合テストに寄せる  
   - 自動テストの安定性が下がる  

## Consequences
- COM解放の安全性が向上する  
- ShowDialogパスのテストが安定し、UI表示に依存しない検証が可能となる  
- COMのネイティブPopupを直接テストしない  
- テストはテストダブルに依存する  