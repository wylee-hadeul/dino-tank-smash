# 🦖 Dino Smash vs Tanks

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

## 개발
```bash
godot --path .                                   # 실행
godot --path . -- --autoplay --shots=/tmp/shots --duration=60   # 오토플레이 봇 + 스크린샷/로그
godot --headless --path . --export-release "Web" docs/index.html # 웹 빌드 (GitHub Pages: main /docs)
```
웹 빌드에서도 `index.html?autoplay` 로 봇 플레이 가능.
