# Neurobits

Neurobits is an adaptive learning app built with Flutter. It combines AI-generated quiz content, personalized onboarding, and exam-aware practice flows with progress analytics and reporting.

- `lib/`: Flutter mobile app
- `convex/`: Convex backend functions and seed data
- `neurobits/`: Next.js website

https://github.com/user-attachments/assets/1abecb0c-1bb5-467e-a4ee-f9cddb115a25

## Current Product Features

- Adaptive quiz generation with mixed formats (`mcq`, `input`, `multi_select`, `ordering`, `fill_blank`, `code`)
- AI-assisted session summaries and performance feedback
- Exam specialization (target selection, year, dates, study capacity)
- Exam dashboard, subject report, and curriculum breakdown screens
- Report center with daily/weekly/monthly views and PNG/PDF export
- Learning paths, streak onboarding, and user preference onboarding

## Requirements

- Flutter `>=3.38.7` (recommended)
- Dart `>=3.8.1 <4.0.0`

## Environment Variables

Create a `.env` file in the repository root.

Primary variable names:

```env
CONVEX_DEPLOYMENT_URL=your_convex_deployment_url
HACKCLUB_API_KEY=your_hackclub_api_key
```

Supported aliases:

```env
CONVEX_URL=your_convex_deployment_url
OPENROUTER_API_KEY=your_hackclub_api_key
```

Both Flutter app and timetable/AI services accept either naming scheme.

## Local Development

Flutter app:

```bash
flutter pub get
flutter run
```

Static checks:

```bash
flutter analyze
flutter test
```

## Website

The site is in `neurobits/`.

```bash
cd neurobits
npm install
npm run dev
```

## License

MIT
