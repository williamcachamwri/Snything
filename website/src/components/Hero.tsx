import { useEffect, useState, useRef } from 'react'
import { motion } from 'framer-motion'
import { Search, ArrowRight, Command, FileText, Image, Zap } from 'lucide-react'

const demoFiles = [
  { name: 'Resume_2024.pdf', icon: FileText, type: 'PDF', size: '2.4 MB' },
  { name: 'Screenshot_001.png', icon: Image, type: 'PNG', size: '1.8 MB' },
  { name: 'main.swift', icon: FileText, type: 'Swift', size: '12 KB' },
  { name: 'Design_Mockup.fig', icon: Image, type: 'Figma', size: '45 MB' },
]

function TypewriterText({ text, delay = 0, onDone }: { text: string; delay?: number; onDone?: () => void }) {
  const [display, setDisplay] = useState('')
  const idx = useRef(0)

  useEffect(() => {
    const timer = setTimeout(() => {
      const interval = setInterval(() => {
        if (idx.current < text.length) {
          setDisplay(text.slice(0, idx.current + 1))
          idx.current++
        } else {
          clearInterval(interval)
          onDone?.()
        }
      }, 60)
      return () => clearInterval(interval)
    }, delay)
    return () => clearTimeout(timer)
  }, [text, delay, onDone])

  return <span>{display}<span className="animate-pulse text-primary">|</span></span>
}

export default function Hero() {
  const [showResults, setShowResults] = useState(false)
  const [typingDone, setTypingDone] = useState(false)

  useEffect(() => {
    if (typingDone) {
      const t = setTimeout(() => setShowResults(true), 300)
      return () => clearTimeout(t)
    }
  }, [typingDone])

  return (
    <section className="relative min-h-screen flex items-center justify-center pt-20 pb-12 px-6">
      <div className="max-w-5xl mx-auto w-full">
        <div className="text-center mb-16">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
          >
            <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 border border-primary/20 text-primary text-xs font-medium mb-8">
              <Zap className="w-3.5 h-3.5" />
              macOS Search, Reinvented
            </span>
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
            className="text-5xl sm:text-6xl lg:text-7xl font-bold tracking-tight leading-[1.1] mb-6"
          >
            Find anything,{' '}
            <span className="text-gradient">instantly</span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.22, 1, 0.36, 1] }}
            className="text-lg sm:text-xl text-text-muted max-w-2xl mx-auto mb-10 leading-relaxed"
          >
            Lightning-fast file search with OCR-powered image search,
            clipboard history, and beautiful previews. Built for macOS.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.3, ease: [0.22, 1, 0.36, 1] }}
            className="flex flex-col sm:flex-row items-center justify-center gap-4"
          >
            <a
              href="#download"
              className="group flex items-center gap-2 px-8 py-4 bg-primary hover:bg-primary-glow text-white font-semibold rounded-full transition-all duration-300 glow-strong"
            >
              Download Free
              <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
            </a>
            <a
              href="#features"
              className="flex items-center gap-2 px-8 py-4 text-text-muted hover:text-text font-medium rounded-full border border-border hover:border-primary/50 transition-all duration-300"
            >
              See how it works
            </a>
          </motion.div>
        </div>

        {/* Search Demo */}
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 1, delay: 0.5, ease: [0.22, 1, 0.36, 1] }}
          className="max-w-2xl mx-auto"
        >
          <div className="glass rounded-2xl p-1.5 glow">
            <div className="flex items-center gap-3 px-4 py-3 bg-surface rounded-xl">
              <Search className="w-5 h-5 text-text-muted shrink-0" />
              <div className="flex-1 text-left text-lg font-mono">
                <TypewriterText
                  text="resum"
                  delay={1200}
                  onDone={() => setTypingDone(true)}
                />
              </div>
              <div className="flex items-center gap-1.5 px-2 py-1 rounded-md bg-surface-light text-text-muted text-xs font-mono">
                <Command className="w-3 h-3" />
                <span>Space</span>
              </div>
            </div>

            {showResults && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
                className="mt-1.5 overflow-hidden"
              >
                {demoFiles.slice(0, 2).map((file, i) => (
                  <motion.div
                    key={file.name}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ duration: 0.4, delay: i * 0.1 }}
                    className={`flex items-center gap-3 px-4 py-3 mx-1 rounded-xl transition-colors ${
                      i === 0 ? 'bg-primary/10' : 'hover:bg-surface-light'
                    }`}
                  >
                    <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${
                      i === 0 ? 'bg-primary/20' : 'bg-surface-light'
                    }`}>
                      <file.icon className={`w-4 h-4 ${i === 0 ? 'text-primary' : 'text-text-muted'}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium truncate">{file.name}</div>
                      <div className="text-xs text-text-muted">{file.type} &middot; {file.size}</div>
                    </div>
                    {i === 0 && (
                      <span className="text-xs text-primary font-medium px-2 py-1 bg-primary/10 rounded-md">
                        Enter to open
                      </span>
                    )}
                  </motion.div>
                ))}
              </motion.div>
            )}
          </div>
        </motion.div>
      </div>
    </section>
  )
}
