'use client';

import { useRef, useEffect } from 'react';
import { Outfit, Manrope } from 'next/font/google';
import Image from 'next/image';
import { motion, useScroll, useTransform, MotionValue } from 'framer-motion';
import Lenis from 'lenis';
import Dither from '../components/Dither';
import CardNav from '../components/CardNav';

const tinos = Outfit({
  subsets: ['latin'],
  weight: ['500', '600', '700', '800'],
  display: 'swap'
});

const montserrat = Manrope({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  display: 'swap'
});

function getChapterTimeline(index: number, total: number) {
  const start = index / total;
  const end = (index + 1) / total;
  const enter = Math.max(0, start - 0.04);
  const exit = Math.min(1, end - 0.03);
  const isLast = index === total - 1;

  return { enter, start, exit, end, isLast };
}

const showcaseImages = [
  '/screenshot-1-App Screenshot.png',
  '/screenshot-2-Tilted Right.png',
  '/screenshot-3-Tilted Right.png',
  '/screenshot-4-Hanged Up.png',
  '/screenshot-5-Tilted Left.png',
  '/screenshot-6-App Screenshot.png',
  '/screenshot-7-Tilted Left.png'
];

const chapters = [
  {
    id: '01',
    title: 'Adaptive difficulty.',
    subtitle: 'It shifts with your answers. Stay in the flow state instead of hitting a wall or getting bored.',
    image: showcaseImages[0]
  },
  {
    id: '02',
    title: 'AI-generated sets.',
    subtitle: 'Fresh challenges engineered for your exact level. No two sessions are ever the same.',
    image: showcaseImages[5]
  },
  {
    id: '03',
    title: 'Retention built-in.',
    subtitle: 'Revisit weak spots automatically. Lock in long-term recall with spaced intervals.',
    image: showcaseImages[3]
  },
  {
    id: '04',
    title: 'Track momentum.',
    subtitle: 'Trends, performance signals, and streaks that build consistency over time.',
    image: showcaseImages[6]
  }
];

function ChapterText({ chapter, index, total, progress }: { chapter: { title: string, subtitle: string }, index: number, total: number, progress: MotionValue<number> }) {
  const { enter, start, exit, end, isLast } = getChapterTimeline(index, total);
  
  const opacity = useTransform(progress, [enter, start, exit, end], [0, 1, 1, isLast ? 1 : 0]);
  const y = useTransform(progress, [enter, start, exit, end], [32, 0, 0, isLast ? 0 : -28]);
  const filter = useTransform(progress, [enter, start, exit, end], ['blur(10px)', 'blur(0px)', 'blur(0px)', isLast ? 'blur(0px)' : 'blur(10px)']);
  
  return (
    <motion.div 
      style={{ opacity, y, filter }} 
      className="absolute inset-0 flex flex-col justify-center pointer-events-none"
    >
      <h2 className={`${tinos.className} text-5xl lg:text-7xl text-white mb-8 leading-[1.02] font-semibold pointer-events-auto`}>
        {chapter.title}
      </h2>
      <p className={`${montserrat.className} text-lg lg:text-xl text-white/75 font-normal leading-relaxed max-w-lg pointer-events-auto [text-shadow:_0_2px_14px_rgba(0,0,0,0.85)]`}>
        {chapter.subtitle}
      </p>
    </motion.div>
  );
}

function ChapterImage({ chapter, index, total, progress }: { chapter: { image: string, title: string }, index: number, total: number, progress: MotionValue<number> }) {
  const { enter, start, exit, end, isLast } = getChapterTimeline(index, total);
  
  const opacity = useTransform(progress, [enter, start, exit, end], [0, 1, 1, isLast ? 1 : 0]);
  const scale = useTransform(progress, [enter, start, exit, end], [0.9, 1, 1.03, isLast ? 1.03 : 1.08]);
  const rotateY = useTransform(progress, [enter, start, exit, end], [10, 0, 0, isLast ? 0 : -6]);
  
  return (
    <motion.div 
      style={{ opacity, scale, rotateY, perspective: 1000 }} 
      className="absolute inset-0 flex items-center justify-center origin-center pointer-events-none"
    >
      <Image 
        src={chapter.image} 
        width={500} 
        height={1000} 
        alt={chapter.title} 
        className="w-auto h-[90%] lg:h-full max-h-[800px] object-contain rounded-[2rem] lg:rounded-[2.5rem] border border-white/5 shadow-[0_30px_80px_rgba(0,0,0,0.8)] bg-[#030108] pointer-events-auto" 
      />
    </motion.div>
  );
}

export default function Home() {
  const demoVideoRef = useRef<HTMLVideoElement>(null);
  const speedNudgeTimerRef = useRef<number | null>(null);

  useEffect(() => {
    const lenis = new Lenis({
      autoRaf: true,
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      gestureOrientation: 'vertical',
      smoothWheel: true,
    });

    return () => {
      lenis.destroy();
    };
  }, []);

  useEffect(() => {
    const video = demoVideoRef.current;
    if (!video) return;

    const clearSpeedNudge = () => {
      if (speedNudgeTimerRef.current !== null) {
        window.clearInterval(speedNudgeTimerRef.current);
        speedNudgeTimerRef.current = null;
      }
    };

    const applySpeed = () => {
      const preferredRates = [8, 6, 5, 4, 3.5];
      let appliedRate = video.playbackRate;

      for (const finalRate of preferredRates) {
        video.defaultPlaybackRate = finalRate;
        video.playbackRate = finalRate;
        appliedRate = video.playbackRate;
        if (appliedRate >= finalRate - 0.01) {
          break;
        }
      }

      clearSpeedNudge();

      if (appliedRate < 3.5) {
        speedNudgeTimerRef.current = window.setInterval(() => {
          if (video.paused || video.seeking || !Number.isFinite(video.duration)) {
            return;
          }

          const nextTime = video.currentTime + 0.22;
          if (nextTime >= video.duration - 0.05) {
            video.currentTime = 0;
            return;
          }
          video.currentTime = nextTime;
        }, 120);
      }
    };

    applySpeed();
    video.addEventListener('loadedmetadata', applySpeed);
    video.addEventListener('play', applySpeed);

    return () => {
      video.removeEventListener('loadedmetadata', applySpeed);
      video.removeEventListener('play', applySpeed);
      clearSpeedNudge();
    };
  }, []);

  const storyRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress: storyProgress } = useScroll({
    target: storyRef,
    offset: ['start start', 'end end']
  });

  return (
    <div className="relative min-h-screen bg-transparent selection:bg-[#7C3AED]/30 selection:text-white">
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

      <div className="relative z-50">
        <CardNav
          logo="/icon.png"
          logoAlt="Neurobits"
          baseColor="rgba(5, 2, 10, 0.4)"
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
                { label: 'Get Latest Build', href: 'https://github.com/hridaya423/neurobits/releases', ariaLabel: 'Get latest build from releases' },
                { label: 'Learn More', href: '#story', ariaLabel: 'Learn more about features' }
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
      </div>

      <div className="content-wrapper z-10 relative" style={{ pointerEvents: 'none' }}>
        <section className="min-h-screen flex items-center justify-center px-6 py-24">
          <div style={{ pointerEvents: 'auto' }} className="max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">
            <div className="text-center lg:text-left order-1">
              <h1 className={`${tinos.className} text-5xl sm:text-6xl md:text-7xl lg:text-9xl font-semibold mb-1 sm:mb-2 lg:mb-3 text-white leading-none tracking-tight`}>
                Neurobits
              </h1>
              <p className={`${montserrat.className} text-lg sm:text-xl md:text-2xl lg:text-3xl text-white/60 font-normal tracking-wide`}>
                Train your brain
              </p>
            </div>
            <div className="order-2 relative z-20 flex items-center justify-center">
              <div className="relative mx-auto overflow-hidden rounded-[2rem] border border-white/20 bg-[#05010d]/85 shadow-[0_32px_120px_rgba(0,0,0,0.65)] w-full max-w-[240px] sm:max-w-[260px] lg:max-w-[280px]">
                <div className="absolute inset-0 bg-gradient-to-t from-[#05010d]/55 via-transparent to-transparent pointer-events-none z-10" />
                <video
                  ref={demoVideoRef}
                  src="https://github.com/user-attachments/assets/1abecb0c-1bb5-467e-a4ee-f9cddb115a25"
                  className="block w-full aspect-[9/19.5] object-cover bg-black"
                  autoPlay
                  loop
                  muted
                  playsInline
                  preload="auto"
                  poster="/screenshot-1-App Screenshot.png"
                />
              </div>
            </div>
          </div>
        </section>
      </div>

      <section id="story" ref={storyRef} className="relative h-[360vh] w-full z-20 bg-transparent">
        <div className="sticky top-0 h-screen w-full flex items-center justify-center overflow-hidden">
          <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(ellipse_at_center,rgba(124,58,237,0.05)_0%,transparent_70%)] z-0" />

          <div className="max-w-7xl mx-auto w-full px-6 grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center h-full relative z-30">
            <div className="lg:col-span-5 relative h-[30vh] lg:h-[40vh] w-full flex flex-col justify-center order-2 lg:order-1">
              {chapters.map((chapter, i) => (
                <ChapterText key={chapter.id} chapter={chapter} index={i} total={chapters.length} progress={storyProgress} />
              ))}
            </div>

            <div className="lg:col-span-7 relative h-[50vh] lg:h-[80vh] w-full flex items-center justify-center order-1 lg:order-2">
              <div className="relative w-full h-full max-w-[450px] lg:max-w-none flex items-center justify-center">
                {chapters.map((chapter, i) => (
                  <ChapterImage key={chapter.id} chapter={chapter} index={i} total={chapters.length} progress={storyProgress} />
                ))}
              </div>
            </div>

          </div>
        </div>
      </section>

      <section className="relative w-full h-screen flex items-center justify-center bg-transparent z-40 overflow-hidden">
        <div className="absolute inset-0 bg-[linear-gradient(to_bottom,rgba(1,0,3,0)_0%,rgba(1,0,3,0.2)_18%,rgba(1,0,3,0.48)_42%,rgba(1,0,3,0.72)_68%,rgba(1,0,3,0.9)_100%)] pointer-events-none z-10" />
        <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-full h-[85vh] bg-[radial-gradient(ellipse_at_bottom,rgba(124,58,237,0.1)_0%,transparent_72%)] pointer-events-none z-10" />

        <div className="text-center relative z-20 px-6 w-full max-w-4xl mx-auto">
          <p className={`${montserrat.className} text-white/70 tracking-[0.5em] text-xs font-semibold uppercase mb-8 [text-shadow:_0_2px_10px_rgba(0,0,0,0.8)]`}>
            The next step
          </p>
          <h2 className={`${tinos.className} text-5xl sm:text-7xl lg:text-[7rem] text-white leading-[0.9] mb-12 drop-shadow-xl`}>
            Begin your training.
          </h2>
          
          <div className="flex flex-col items-center justify-center gap-6">
            <a
              href="https://github.com/hridaya423/neurobits/releases"
              className={`${montserrat.className} inline-flex items-center justify-center rounded-full px-8 sm:px-10 py-4 sm:py-[1.125rem] bg-white text-[#030108] text-sm sm:text-base font-semibold tracking-wide transition-[transform,box-shadow,background-color] duration-300 ease-out min-w-[220px] hover:-translate-y-0.5 hover:bg-white/95 hover:shadow-[0_12px_32px_rgba(0,0,0,0.35)]`}
            >
              Download Latest Build
            </a>
            
            <a
              href="https://github.com/hridaya423/neurobits"
              className={`${montserrat.className} text-white/70 hover:text-white text-xs sm:text-sm tracking-widest uppercase underline underline-offset-8 decoration-white/35 hover:decoration-white/60 transition-all duration-300 [text-shadow:_0_2px_10px_rgba(0,0,0,0.8)]`}
            >
              View Source Code
            </a>
          </div>
        </div>
      </section>
    </div>
  );
}
