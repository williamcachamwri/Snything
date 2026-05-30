import { useEffect, useRef, useState } from 'react'
import { Command, Type, Eye, ArrowRight } from 'lucide-react'

const steps = [
  {
    number: '01',
    title: 'Summon',
    description: 'Press your global hotkey from anywhere on macOS. Snything appears instantly over any app.',
    icon: Command,
  },
  {
    number: '02',
    title: 'Type',
    description: 'Start typing a filename, OCR text, or even a math expression. Results update in real-time.',
    icon: Type,
  },
  {
    number: '03',
    title: 'Preview & Open',
    description: 'Arrow through results, preview files without leaving, and press Enter to open.',
    icon: Eye,
  },
]

export default function HowItWorks() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const el = sectionRef.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true)
          observer.unobserve(el)
        }
      },
      { threshold: 0.15 }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return (
    <section id="how-it-works" className="py-32 px-6 bg-gradient-to-b from-transparent via-surface/30 to-transparent" ref={sectionRef}>
      <div className="max-w-6xl mx-auto">
        <div
          className="text-center mb-24"
          style={{
            opacity: visible ? 1 : 0,
            transform: visible ? 'translateY(0)' : 'translateY(20px)',
            transition: 'opacity 0.7s ease, transform 0.7s ease',
          }}
        >
          <span className="text-primary text-sm font-semibold tracking-widest uppercase">How it works</span>
          <h2 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold mt-4 tracking-tight">
            Three steps to{' '}
            <span className="text-gradient">find anything</span>
          </h2>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 lg:gap-12 relative">
          {/* Connecting line for desktop */}
          <div className="hidden lg:block absolute top-20 left-[16%] right-[16%] h-0.5">
            <div className="absolute inset-0 bg-gradient-to-r from-blue-500/30 via-primary/30 to-emerald-500/30 rounded-full" />
            <div 
              className="absolute left-0 top-0 h-full bg-gradient-to-r from-blue-500 via-primary to-emerald-500 rounded-full"
              style={{
                width: visible ? '100%' : '0%',
                transition: 'width 2s cubic-bezier(0.22, 1, 0.36, 1)',
                transitionDelay: '0.5s',
              }}
            />
          </div>

          {steps.map((step, i) => (
            <div
              key={step.number}
              className="relative flex flex-col items-center text-center"
              style={{
                opacity: visible ? 1 : 0,
                transform: visible ? 'translateY(0)' : 'translateY(40px)',
                transition: `opacity 0.7s ${i * 0.2}s ease, transform 0.7s ${i * 0.2}s cubic-bezier(0.22, 1, 0.36, 1)`,
              }}
            >
              <div className="relative mb-8 z-10">
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-surface to-surface-light border border-border flex items-center justify-center shadow-xl shadow-black/20">
                  <step.icon className="w-6 h-6 text-primary" />
                </div>
                <span className="absolute -top-2 -right-2 w-7 h-7 rounded-full bg-gradient-to-br from-primary to-blue-500 text-white text-xs font-bold flex items-center justify-center shadow-lg shadow-primary/30">
                  {step.number}
                </span>
              </div>

              <h3 className="text-xl font-bold mb-3">{step.title}</h3>
              <p className="text-text-muted text-sm leading-relaxed max-w-xs">
                {step.description}
              </p>

              {i < steps.length - 1 && (
                <div className="hidden lg:flex absolute top-20 left-full w-12 items-center justify-center z-0">
                  <ArrowRight className="w-5 h-5 text-border" />
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
