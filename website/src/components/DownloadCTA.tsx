import { useEffect, useRef, useState } from 'react'
import { Apple, Check, ArrowRight, Sparkles } from 'lucide-react'

const requirements = [
  'macOS 14.0 or later',
  'Apple Silicon or Intel',
  'Free forever',
  'Open source',
]

export default function DownloadCTA() {
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
      { threshold: 0.2 }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return (
    <section id="download" className="py-32 px-6" ref={sectionRef}>
      <div
        className="max-w-4xl mx-auto"
        style={{
          opacity: visible ? 1 : 0,
          transform: visible ? 'translateY(0)' : 'translateY(40px)',
          transition: 'opacity 0.8s cubic-bezier(0.22, 1, 0.36, 1), transform 0.8s cubic-bezier(0.22, 1, 0.36, 1)',
        }}
      >
        <div className="relative overflow-hidden rounded-3xl gradient-border p-1">
          <div className="relative bg-surface rounded-[22px] p-8 sm:p-12 lg:p-16 text-center overflow-hidden">
            {/* Background effects */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[600px] h-[300px] bg-gradient-to-b from-primary/15 to-transparent rounded-full blur-[100px] pointer-events-none" />
            <div className="absolute bottom-0 right-0 w-[300px] h-[200px] bg-blue-500/10 rounded-full blur-[80px] pointer-events-none" />

            <div className="relative z-10">
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-primary to-blue-500 mb-8 shadow-lg shadow-primary/30">
                <Sparkles className="w-7 h-7 text-white" />
              </div>

              <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight mb-5">
                Ready to find anything,{' '}
                <span className="text-gradient">instantly?</span>
              </h2>

              <p className="text-text-muted text-lg max-w-lg mx-auto mb-10 leading-relaxed">
                Download Snything for free and never waste time searching for files again.
              </p>

              <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-10">
                <a
                  href="https://github.com/williamcachamwri/Snything/releases/latest"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group flex items-center gap-3 px-8 py-4 bg-gradient-to-r from-primary to-blue-500 hover:from-blue-500 hover:to-primary text-white font-semibold rounded-full transition-all duration-500 shadow-xl shadow-primary/30 hover:shadow-primary/50 hover:scale-105"
                >
                  <Apple className="w-5 h-5" />
                  Download for macOS
                  <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform duration-300" />
                </a>
                <a
                  href="https://github.com/williamcachamwri/Snything"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-2 px-6 py-4 text-text-muted hover:text-text font-medium rounded-full border border-border hover:border-primary/40 hover:bg-primary/5 transition-all duration-300"
                >
                  View on GitHub
                </a>
              </div>

              <div className="flex flex-wrap items-center justify-center gap-x-8 gap-y-3">
                {requirements.map((req) => (
                  <div key={req} className="flex items-center gap-2 text-sm text-text-muted">
                    <Check className="w-4 h-4 text-emerald-400" />
                    {req}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
