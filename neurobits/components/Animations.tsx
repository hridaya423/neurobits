'use client';

import { useRef } from 'react';
import { motion, useScroll, useTransform, useSpring } from 'framer-motion';

export function Parallax({
  children,
  offset = 50,
  stiffness = 400,
  damping = 90,
  className = ''
}: {
  children: React.ReactNode;
  offset?: number;
  stiffness?: number;
  damping?: number;
  className?: string;
}) {
  const ref = useRef(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start end', 'end start']
  });

  const smoothProgress = useSpring(scrollYProgress, { stiffness, damping });
  const y = useTransform(smoothProgress, [0, 1], [offset, -offset]);

  return (
    <motion.div ref={ref} style={{ y }} className={className}>
      {children}
    </motion.div>
  );
}

export function FadeIn({
  children,
  delay = 0,
  duration = 0.8,
  yOffset = 40,
  className = '',
  viewMargin = "-100px"
}: {
  children: React.ReactNode;
  delay?: number;
  duration?: number;
  yOffset?: number;
  className?: string;
  viewMargin?: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: yOffset }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: viewMargin }}
      transition={{
        duration,
        delay,
        ease: [0.16, 1, 0.3, 1] // Custom ease-out
      }}
      className={className}
    >
      {children}
    </motion.div>
  );
}
