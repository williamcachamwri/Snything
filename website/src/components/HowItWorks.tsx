import { useEffect, useRef } from 'react'
import { Command, Type, Eye } from 'lucide-react'

const steps = [
  { number: '01', title: 'Summon', description: 'Press your global hotkey. Snything appears instantly over any app.', icon: Command },
  { number: '02', title: 'Type', description: 'Start typing a filename or OCR text. Results update in real-time.', icon: Type },
  { number: '03', title: 'Open', description: 'Arrow through results, preview files, press Enter to open.', icon: Eye },
]

function useReveal(ref: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) { el.classList.add('visible'); observer.unobserve(el) }
    }, { threshold: 0.15 })
    observer.observe(el)
    return () => observer.disconnect()
  }, [ref])
}

export default function HowItWorks() {
  const sectionRef = useRef<HTMLDivElement>(null)
  useReveal(sectionRef)

  return (
    <section id="how-it-works" className="py-32 px-6 bg-[#0a0a0c]/50" ref={sectionRef}>
      <div className="max-w-5xl mx-auto">
        <div className="reveal text-center mb-24">
          <span className="text-[#3b82f6] text-[11px] font-semibold tracking-[0.15em] uppercase">How it works</span>
          <h2 className="text-4xl sm:text-5xl lg:text-[3.5rem] font-extrabold mt-4 tracking-tight leading-[1.1]">
            Three steps to{' '}
            <span className="text-gradient">find anything</span>
          </h2>
        </div>

        <div className="relative grid grid-cols-1 lg:grid-cols-3 gap-12 lg:gap-8">
          <div className="hidden lg:block absolute top-10 left-[20%] right-[20%] h-[1px]">
            <div className="absolute inset-0 bg-[#1f1f23]" />
            <div className="reveal h-full bg-gradient-to-r from-[#3b82f6] via-[#6366f1] to-[#3b82f6] rounded-full" style={{ transitionDelay: '0.4s' }} />
          </div>

          {steps.map((step, i) => (
            <StepCard key={step.number} step={step} index={i} />
          ))}
        </div>
      </div>
    </section>
  )
}

function StepCard({ step, index }: { step: typeof steps[0]; index: number }) {
  const ref = useRef<HTMLDivElement>(null)
  useReveal(ref)

  return (
    <div ref={ref} className="reveal relative flex flex-col items-center text-center" style={{ transitionDelay: `${index * 0.15 + 0.2}s` }}>
      <div className="relative mb-8 z-10">
        <div className="w-20 h-20 rounded-2xl bg-[#111113] border border-[#1f1f23] flex items-center justify-center shadow-lg shadow-black/20">
          <step.icon className="w-6 h-6 text-[#3b82f6]" strokeWidth={1.5} />
        </div>
        <span className="absolute -top-1.5 -right-1.5 w-6 h-6 rounded-full bg-[#3b82f6] text-white text-[10px] font-bold flex items-center justify-center shadow-md shadow-[#3b82f6]/20">
          {step.number}
        </span>
      </div>
      <h3 className="text-lg font-bold mb-2">{step.title}</h3>
      <p className="text-[13px] text-[#8e8e93] leading-relaxed max-w-xs">{step.description}</p>
    </div>
  )
}
