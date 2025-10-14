# Neurobits

A brain training app that uses AI to generate personalized learning challenges. Built with Flutter and uses Hackclub AI for now, it adapts to how you learn and keeps things interesting with daily challenges.

## What it does

This app generates quiz content on the fly based on your progress and preferences. Instead of following a fixed path, the AI creates new challenges and adjusts difficulty as you go. You can track streaks, review past challenges, and follow learning paths that match your goals.

The main idea is to make learning feel less repetitive by generating fresh content each time, while still tracking your progress and keeping you challenged at the right level.

## Features

- AI-generated learning challenges
- Dynamic difficulty that adjusts based on your performance
- Daily challenges to build consistency
- Learning streaks and progress tracking
- Custom learning paths tailored to your goals
- Review functionality for completed challenges
- User authentication and data storage via Supabase



https://github.com/user-attachments/assets/7859dc25-2acf-4062-b873-e490139d32fe



## Getting Started

This project requires Flutter to be installed.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/hridaya423/neurobits
    cd neurobits
    ```
2.  **Set up environment variables:**
    *   Create a `.env` file in the root directory.
        ```
        SUPABASE_URL=YOUR_SUPABASE_URL
        SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
        ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Run the app:**
    ```bash
    flutter run
    ```

## License

MIT LICENSE
