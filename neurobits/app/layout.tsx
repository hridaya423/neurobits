import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "Neurobits",
    template: "%s | Neurobits",
  },
  description:
    "Neurobits is an adaptive learning app that sharpens problem-solving with AI-generated question sets, spaced retention, and progress tracking.",
  applicationName: "Neurobits",
  keywords: [
    "Neurobits",
    "adaptive learning",
    "AI quiz app",
    "spaced repetition",
    "exam practice",
    "brain training",
  ],
  authors: [{ name: "Neurobits" }],
  creator: "Neurobits",
  publisher: "Neurobits",
  category: "education",
  icons: {
    icon: [{ url: "/icon.png", type: "image/png" }],
    shortcut: ["/icon.png"],
    apple: [{ url: "/icon.png" }],
  },
  openGraph: {
    title: "Neurobits",
    description:
      "Adaptive difficulty, AI-generated sets, and retention-driven practice that keeps you in flow.",
    type: "website",
    images: [
      {
        url: "/icon.png",
        width: 512,
        height: 512,
        alt: "Neurobits logo",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Neurobits",
    description:
      "Adaptive learning with AI-generated practice and retention-focused study loops.",
    images: ["/icon.png"],
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
