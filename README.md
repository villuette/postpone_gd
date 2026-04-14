# Project: Postpone

Прототип шутера от первого лица на движке **Godot 4.x (Forward Mobile)**. Проект ориентирован на механики управления состоянием (HP, Mind, Stamina) и модульную настройку через внутриигровое меню.

## 🛠 Tech Stack
* **Engine:** Godot 4.x (Forward Mobile)
* **OS:** Debian Sid (Unstable / Trixie)
* **Hardware:** NVIDIA GTX 1650 (4GB VRAM)
* **Python Stack:** `uv` (project management), `PyTorch`
* **Shell/CLI:** Zsh (Antidote + P10k), `zoxide`, `fzf-tab`
* **Tools:** `eza`, `bat`, `ripgrep`, `fd`
* **Editors:** `micro` (CLI), `Zed` / `Alacritty`

## 🕹 Key Mechanics
* **Hybrid Stat System:**
    * `Mind` & `Health`: Логические "тики" урона раз в секунду. Сначала истощается ментальное состояние, затем — здоровье.
    * `Stamina`: Плавный расход при беге и регенерация в реальном времени (`delta`-based).
* **Vignette System:** Динамическое покраснение экрана при низком уровне здоровья (пульсация через `Tween`).
* **Global Input:** Управление паузой через независимый от игрока UI-слой (`Process Mode: Always`).
* **Smooth UI:** Анимированные прогресс-бары с использованием `StyleBoxFlat` и интерполяции `Tween`.

## 🚀 Installation & Running
Для работы в окружении Debian Sid:

1. Склонируйте репозиторий:
    ```bash
    git clone <repo_url>
    cd <project_dir>
    ```
2. Открытие проекта в Godot:
    ```bash
    godot4 --editor project.godot
    ```


## 🏗 Project Structure
* `/src`: HUD, VBoxContainer со шкалами, меню паузы.
* `/assets`: Текстуры, градиенты для виньетки.

## 📋 TODO
- [ ] Система инвентаря.
- [ ] Реализация полноценного цикла смерти.
- [ ] AI Агенты (MCP) и Rust-модули.

## 📜 License
-
