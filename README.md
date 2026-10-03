# 🦖 공룡 대난동 vs 탱크 군단

Godot 4.6로 만든 공룡이 탱크를 부수는 2D 액션 게임. 모바일 웹(가로 모드)과 데스크톱 모두 지원.

**플레이:** https://wylee-hadeul.github.io/dino-tank-smash/

## 조작
| 동작 | 키보드 | 모바일 |
|---|---|---|
| 이동 | A/D, ←/→ | ◀ ▶ |
| 점프 (탱크 밟기) | W, Space, ↑ | JUMP |
| 물기 (포탄 받아치기) | J, Z, F | BITE |
| 포효 (게이지 100%) | K, X, E | ROAR |

- 날아오는 포탄을 물면 탱크 쪽으로 되돌려 보낸다 (3배 데미지)
- 웨이브 3부터 헬기 등장 — 점프해서 물기
- 연속 처치 시 콤보 배수 (최대 x5)
- **웨이브 클리어 시 능력 강화 카드 3장 중 1개 선택** (11종, 중첩 가능)
  - 체력/물기 데미지/물기 범위/이동속도/점프·밟기/포효/방어/흡혈/반사 데미지/물기 쿨타임/재생

## 개발
```bash
godot --path .                                   # 실행
godot --path . -- --autoplay --shots=/tmp/shots --duration=60   # 오토플레이 봇 + 스크린샷/로그
./tools/export_web.sh   # 웹 빌드 + 캐시 무효화 (GitHub Pages: main /docs)
```
웹 빌드에서도 `index.html?autoplay` 로 봇 플레이 가능 (`&manualpick` 을 붙이면 강화 카드는 직접 선택).

## 폰트
게임 내 한글 폰트: [Jua](https://fonts.google.com/specimen/Jua) (SIL Open Font License 1.1, `fonts/OFL.txt`)
