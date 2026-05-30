import { useEffect, useRef } from 'react'
import { Apple, ArrowRight, Check } from 'lucide-react'

const requirements = [
  'macOS 14.0 or later',
  'Apple Silicon or Intel',
  'Free forever',
  'Open source',
]

function useReveal(ref: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) { el.classList.add('visible'); observer.unobserve(el) }
    }, { threshold: 0.2 })
    observer.observe(el)
    return () => observer.disconnect()
  }, [ref])
}

export default function DownloadCTA() {
  const sectionRef = useRef<HTMLDivElement>(null)
  useReveal(sectionRef)

  return (
    <section id="download" className="py-32 px-6" ref={sectionRef}>
      <div className="reveal max-w-3xl mx-auto">
        <div className="relative rounded-3xl border border-[#1f1f23] bg-[#0d0d10] p-10 sm:p-14 lg:p-16 text-center overflow-hidden">
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[500px] h-[250px] bg-[#3b82f6]/8 rounded-full blur-[100px] pointer-events-none" />

          <div className="relative z-10">
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-xl bg-[#3b82f6]/10 mb-8">
              <Apple className="w-5 h-5 text-[#3b82f6]" />
            </div>

            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight mb-5 leading-[1.15]">
              Ready to find anything,{' '}
              <span className="text-gradient">instantly?</span>
            </h2>

            <p className="text-[#8e8e93] text-[17px] max-w-md mx-auto mb-10 leading-relaxed">
              Download Snything for free and never waste time searching for files again.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 mb-10">
              <a
                href="https://github.com/williamcachamwri/Snything/releases/latest"
                target="_blank"
                rel="noopener noreferrer"
                className="group flex items-center gap-2.5 px-7 py-3 text-[14px] font-semibold text-white bg-[#3b82f6] hover:bg-[#2563eb] rounded-full transition-all duration-300 hover:shadow-[0_0_30px_-8px_rgba(59,130,246,0.45)]"
              >
                <Apple className="w-4 h-4" />
                Download for macOS
                <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-0.5" />
              </a>
              <a
                href="https://github.com/williamcachamwri/Snything"
                target="_blank"
                rel="noopener noreferrer"
                className="px-7 py-3 text-[14px] font-medium text-[#8e8e93] hover:text-[#f1f1f3] rounded-full border border-[#2a2a2e] hover:border-[#3b82f6]/30 transition-all duration-300"
              >
                View on GitHub
              </a>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-x-8 gap-y-2.5">
              {requirements.map((req) => (
                <div key={req} className="flex items-center gap-2 text-[12px] text-[#8e8e93]">
                  <Check className="w-3.5 h-3.5 text-emerald-400" strokeWidth={2.5} />
                  {req}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
