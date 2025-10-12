'use client';

import { Tinos, Montserrat } from 'next/font/google';
import Dither from '../components/Dither';
import CardNav from '../components/CardNav';
import RollingGallery from '../components/RollingGallery';
import Banner from '../components/Banner';

const tinos = Tinos({
  subsets: ['latin'],
  weight: ['400', '700'],
  display: 'swap'
});

const montserrat = Montserrat({
  subsets: ['latin'],
  weight: ['300', '400'],
  display: 'swap'
});

export default function Home() {
  const showcaseImages = [
    '/screenshot-1-App Screenshot.png',
    '/screenshot-2-Tilted Right.png',
    '/screenshot-3-Tilted Right.png',
    '/screenshot-4-Hanged Up.png',
    '/screenshot-5-Tilted Left.png',
    '/screenshot-6-App Screenshot.png',
    '/screenshot-7-Tilted Left.png'
  ];

  return (
    <div className="relative min-h-screen">
      <Banner message="Yer a wizard, the magic update is now live! Go try it!" storageKey="magic-update-banner" />
      <div style={{
        width: '100%',
        height: '100vh',
        position: 'fixed',
        top: 0,
        left: 0,
        zIndex: 0,
        pointerEvents: 'all'
      }}>
        <Dither
          waveColor={[0.48, 0.15, 0.93]}
          disableAnimation={false}
          enableMouseInteraction={true}
          mouseRadius={0.3}
          colorNum={4}
          waveAmplitude={0.3}
          waveFrequency={3}
          waveSpeed={0.05}
        />
      </div>

      <CardNav
        logo="/icon.png"
        logoAlt="Neurobits"
        baseColor="rgba(10, 6, 18, 0.7)"
        menuColor="#E9D5FF"
        buttonBgColor="#7C3AED"
        buttonTextColor="#FFFFFF"
        items={[
          {
            label: 'GitHub Repo',
            bgColor: '#7C3AED',
            textColor: '#FFFFFF',
            links: [
              { label: 'View Repository', href: 'https://github.com/hridaya423/neurobits', ariaLabel: 'View GitHub repository' },
              { label: 'Contribute', href: 'https://github.com/hridaya423/neurobits/contribute', ariaLabel: 'Contribute to the project' }
            ]
          },
          {
            label: 'App Store Download',
            bgColor: '#5B21B6',
            textColor: '#FFFFFF',
            links: [
              { label: 'Download on iOS', href: '#app-store', ariaLabel: 'Download on App Store' },
              { label: 'View Screenshots', href: '#ios-screenshots', ariaLabel: 'View iOS screenshots' }
            ]
          },
          {
            label: 'Play Store Download',
            bgColor: '#6D28D9',
            textColor: '#FFFFFF',
            links: [
              { label: 'Download APK', href: 'https://github.com/hridaya423/neurobits/releases/tag/v1.0.0', ariaLabel: 'Download Android APK' },
              { label: 'View All Releases', href: 'https://github.com/hridaya423/neurobits/releases', ariaLabel: 'View all releases' }
            ]
          }
        ]}
        githubUrl="https://github.com/hridaya423/neurobits"
      />

      <div className="content-wrapper" style={{ pointerEvents: 'none' }}>
        <section className="min-h-screen flex items-center justify-center px-6 py-24">
          <div style={{ pointerEvents: 'auto' }} className="max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">
            <div className="text-center lg:text-left order-2 lg:order-1">
              <h1 className={`${tinos.className} text-5xl sm:text-6xl md:text-7xl lg:text-9xl font-bold mb-6 lg:mb-8 text-white leading-none tracking-tight`}>
                Neurobits
              </h1>
              <p className={`${montserrat.className} text-lg sm:text-xl md:text-2xl lg:text-3xl text-white/60 font-light tracking-wide`}>
                Train your brain
              </p>
            </div>
            <div className="order-1 lg:order-2 scale-75 lg:scale-100">
              <RollingGallery
                images={showcaseImages}
                autoplay={true}
                pauseOnHover={true}
              />
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
