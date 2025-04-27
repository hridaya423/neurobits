# Neurobits

Neurobits offers a unique and personal learning experience, leveraging adaptive AI to move beyond basic brain training. It crafts tailored learning paths and daily challenges designed specifically for your preferences, skill level, and goals, ensuring a truly individualized journey.

## Why Neurobits?

*   **Truly Personalized:** Unlike generic apps, Neurobits creates special learning paths and challenges just for you.
*   **Adaptive AI:** Advanced AI generates fresh content on demand, adjusts difficulty to match your progress, and provides immediate, helpful feedback.
*   **Beyond Memorization:** Focuses on deeper learning and engagement, helping you reach your goals faster.
*   **Stay Motivated:** Tracks learning streaks, visualizes progress, and allows review of completed content to keep you engaged and challenged appropriately.

## Features

*   **Personalized Learning Paths:** AI-generated or curated journeys tailored to individual user needs and goals.
*   **Adaptive Daily Challenges:** Keeps learning fresh and appropriately difficult based on user progress.
*   **On-Demand Content Generation:** AI creates new learning material as needed.
*   **Dynamic Difficulty Adjustment:** Ensures users are always challenged at the right level.
*   **Instant Feedback:** Provides immediate insights to aid the learning process.
*   **Progress Tracking:** Monitors learning streaks and overall progress.
*   **Review Functionality:** Allows revisiting completed material.
*   **Supabase Backend:** Securely handles user authentication, data storage (stats, progress), and other backend needs.
*   **Smooth User Experience:** Built with Flutter and Riverpod for a responsive interface, featuring onboarding, notifications, and potentially drag-and-drop interactions.

## Getting Started

This project requires Flutter to be installed.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/hridaya423/neurobits
    cd neurobits
    ```
2.  **Set up environment variables:**
    *   Create a `.env` file in the root directory.
    *   Add the necessary Supabase and Groq API keys/URLs:
        ```
        SUPABASE_URL=YOUR_SUPABASE_URL
        SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
        GROQ_API_KEY=YOUR_GROQ_API_KEY
        ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Run the app:**
    ```bash
    flutter run
    ```

## Project Structure (Key Directories)

*   `lib/core`: Core utilities, router, widgets, providers.
*   `lib/features`: Application features (e.g., onboarding, learning paths, daily challenges).
*   `lib/services`: Services for interacting with external APIs (Supabase, Groq).
*   `lib/models`: Data models used throughout the application.
*   `assets`: Static assets like images, fonts, and the `.env` file configuration.


## License

MIT LICENSE
