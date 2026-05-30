import { useEffect, useState, useRef } from 'react'
import { Search, ArrowRight, Zap, FileText, Image, Video, Music } from 'lucide-react'

const demoFiles = [
  { name: 'Resume_2024.pdf', icon: FileText, type: 'PDF', size: '2.4 MB', category: 'document' },
  { name: 'Screenshot_001.png', icon: Image, type: 'PNG', size: '1.8 MB', category: 'image' },
  { name: 'main.swift', icon: FileText, type: 'Swift', size: '12 KB', category: 'code' },
  { name: 'Design_Mockup.fig', icon: Image, type: 'Figma', size: '45 MB', category: 'design' },
  { name: 'Meeting_Recording.mov', icon: Video, type: 'MOV', size: '156 MB', category: 'video' },
  { name: 'Podcast_Ep12.mp3', icon: Music, type: 'MP3', size: '28 MB', category: 'audio' },
]

const typewriterTexts = [
  'resum',
  'screenshot',
  'main.sw',
  'design',
  'meeting',
  'podcast',
]

export default function Hero() {
  const [currentText, setCurrentText] = useState('')
  const [textIndex, setTextIndex] = useState(0)
  const [showResults, setShowResults] = useState(false)
  const [typingPhase, setTypingPhase] = useState<'typing' | 'deleting' | 'waiting'>('waiting')
  const typingTimeout = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    const fullText = typewriterTexts[textIndex]
    let currentLen = currentText.length

    const delay = 800
    const typeSpeed = 80
    const deleteSpeed = 40

    if (typingPhase === 'waiting') {
      typingTimeout.current = setTimeout(() => {
        setTypingPhase('typing')
        setShowResults(false)
      }, delay)
      return
    }

    if (typingPhase === 'typing') {
      if (currentLen < fullText.length) {
        typingTimeout.current = setTimeout(() => {
          setCurrentText(fullText.slice(0, currentLen + 1))
        }, typeSpeed)
      } else {
        setShowResults(true)
        typingTimeout.current = setTimeout(() => {
          setTypingPhase('deleting')
        }, 2000)
      }
      return
    }

    if (typingPhase === 'deleting') {
      if (currentLen > 0) {
        typingTimeout.current = setTimeout(() => {
          setCurrentText(fullText.slice(0, currentLen - 1))
        }, deleteSpeed)
      } else {
        typingTimeout.current = setTimeout(() => {
          setTextIndex((prev) => (prev + 1) % typewriterTexts.length)
          setTypingPhase('waiting')
        }, 400)
      }
      return
    }

    return () => {
      if (typingTimeout.current) clearTimeout(typingTimeout.current)
    }
  }, [currentText, textIndex, typingPhase])

  const filtered = demoFiles.filter(f =>
    f.name.toLowerCase().includes(currentText.toLowerCase())
  )

  return (
    <section className="relative min-h-screen flex items-center justify-center pt-24 pb-16 px-6 overflow-hidden">
      {/* Floating decorative elements */}
      <div className="absolute top-[20%] left-[10%] w-20 h-20 rounded-full bg-blue-500/10 blur-xl animate-float" />
      <div className="absolute top-[60%] right-[8%] w-32 h-32 rounded-full bg-purple-500/10 blur-xl animate-float-reverse" />
      <div className="absolute bottom-[20%] left-[20%] w-24 h-24 rounded-full bg-emerald-500/8 blur-xl animate-float-slow" />

      <div className="max-w-5xl mx-auto w-full">
        <div className="text-center mb-20">
          <div style={{ animation: 'slide-up 0.8s 0.2s cubic-bezier(0.22, 1, 0.36, 1) forwards', opacity: 0 }}>
            <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-gradient-to-r from-blue-500/10 to-primary/10 border border-primary/20 text-primary text-xs font-semibold tracking-wide uppercase">
              <Zap className="w-3.5 h-3.5" />
              macOS Search, Reinvented
            </span>
          </div>

          <h1
            className="text-5xl sm:text-6xl lg:text-7xl font-extrabold tracking-tight leading-[1.1] mt-8 mb-6"
            style={{ animation: 'slide-up 0.8s 0.3s cubic-bezier(0.22, 1, 0.36, 1) forwards', opacity: 0 }}
          >
            Find anything,{' '}
            <span className="text-gradient">instantly</span>
          </h1>

          <p
            className="text-lg sm:text-xl text-text-muted max-w-2xl mx-auto mb-10 leading-relaxed"
            style={{ animation: 'slide-up 0.8s 0.4s cubic-bezier(0.22, 1, 0.36, 1) forwards', opacity: 0 }}
          >
            Lightning-fast file search with OCR-powered image search,
            clipboard history, and beautiful previews. Built for macOS.
          </p>

          <div
            className="flex flex-col sm:flex-row items-center justify-center gap-4"
            style={{ animation: 'slide-up 0.8s 0.5s cubic-bezier(0.22, 1, 0.36, 1) forwards', opacity: 0 }}
          >
            <a
              href="#download"
              className="group flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-primary to-blue-500 hover:from-blue-500 hover:to-primary text-white font-semibold rounded-full transition-all duration-500 shadow-lg shadow-primary/30 hover:shadow-primary/50 hover:scale-105"
            >
              Download Free
              <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform duration-300" />
            </a>
            <a
              href="#features"
              className="flex items-center gap-2 px-8 py-4 text-text-muted hover:text-text font-medium rounded-full border border-border hover:border-primary/40 hover:bg-primary/5 transition-all duration-300"
            >
              See how it works
            </a>
          </div>
        </div>

        {/* Search Demo */}
        <div
          className="max-w-2xl mx-auto"
          style={{ animation: 'scale-in 1s 0.7s cubic-bezier(0.22, 1, 0.36, 1) forwards', opacity: 0 }}
        >
          <div className="glass rounded-2xl p-2 shadow-2xl shadow-black/30">
            <div className="flex items-center gap-3 px-4 py-3.5 bg-surface rounded-xl border border-border/50">
              <Search className="w-5 h-5 text-text-muted shrink-0" />
              <div className="flex-1 text-left text-base font-mono text-text">
                <span>{currentText}</span>
                <span className="animate-cursor text-primary ml-0.5">|</span>
              </div>
              <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-surface-light border border-border/50 text-text-muted text-xs font-mono">
                <span className="text-[10px]">&#8984;</span>
                <span>Space</span>
              </div>
            </div>

            <div className={`mt-2 transition-all duration-500 overflow-hidden ${showResults && currentText.length > 0 ? 'max-h-80 opacity-100' : 'max-h-0 opacity-0'}`}>
              <div className="px-1 pb-1">
                {filtered.length > 0 ? (
                  filtered.slice(0, 4).map((file, i) => (
                    <div
                      key={file.name}
                      className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 hover:bg-surface-light/80 cursor-default ${
                        i === 0 ? 'bg-primary/5' : ''
                      }`}
                      style={{
                        animation: showResults ? `slide-up 0.4s ${i * 0.06}s cubic-bezier(0.22, 1, 0.36, 1) forwards` : 'none',
                        opacity: 0,
                      }}
                    >
                      <div className={`w-9 h-9 rounded-lg flex items-center justify-center shrink-0 ${
                        i === 0 ? 'bg-primary/15' : 'bg-surface-light'
                      }`}>
                        <file.icon className={`w-4 h-4 ${i === 0 ? 'text-primary' : 'text-text-muted'}`} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="text-sm font-medium truncate">
                          {file.name.split(new RegExp(`(${currentText})`, 'gi')).map((part, idx) =>
                            part.toLowerCase() === currentText.toLowerCase() ? (
                              <span key={idx} className="text-primary font-semibold bg-primary/10 rounded px-0.5">{part}</span>
                            ) : (
                              <span key={idx}>{part}</span>
                            )
                          )}
                        </div>
                        <div className="text-xs text-text-muted">{file.type} · {file.size}</div>
                      </div>
                      {i === 0 && (
                        <span className="text-xs text-primary font-medium px-2 py-1 bg-primary/10 rounded-md shrink-0">
                          Enter
                        </span>
                      )}
                    </div>
                  ))
                ) : (
                  <div className="px-4 py-8 text-center text-text-muted text-sm">
                    No results found
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
