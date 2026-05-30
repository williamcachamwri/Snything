import { useEffect, useRef } from 'react'
import { Search, Eye, History, Zap, Command, Layers } from 'lucide-react'

const features = [
  { icon: Search, title: 'Instant Search', description: 'Type and see results in milliseconds. No indexing delays.', color: 'text-blue-400', bg: 'bg-blue-500/8', border: 'border-blue-500/10' },
  { icon: Eye, title: 'OCR Image Search', description: 'Search text inside screenshots and photos automatically.', color: 'text-purple-400', bg: 'bg-purple-500/8', border: 'border-purple-500/10' },
  { icon: History, title: 'Clipboard History', description: 'Browse and search everything you have ever copied.', color: 'text-emerald-400', bg: 'bg-emerald-500/8', border: 'border-emerald-500/10' },
  { icon: Zap, title: 'Beautiful Previews', description: 'Preview images, videos, PDFs, and code without leaving.', color: 'text-amber-400', bg: 'bg-amber-500/8', border: 'border-amber-500/10' },
  { icon: Command, title: 'Global Hotkey', description: 'Summon Snything from anywhere with a single keystroke.', color: 'text-rose-400', bg: 'bg-rose-500/8', border: 'border-rose-500/10' },
  { icon: Layers, title: 'Smart Rankings', description: 'Ranked by relevance, recency, and access frequency.', color: 'text-cyan-400', bg: 'bg-cyan-500/8', border: 'border-cyan-500/10' },
]

function useReveal(ref: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) { el.classList.add('visible'); observer.unobserve(el) }
    }, { threshold: 0.12 })
    observer.observe(el)
    return () => observer.disconnect()
  }, [ref])
}

export default function Features() {
  const headerRef = useRef<HTMLDivElement>(null)
  useReveal(headerRef)

  return (
    <section id="features" className="py-32 px-6">
      <div className="max-w-5xl mx-auto">
        <div ref={headerRef} className="reveal text-center mb-20">
          <span className="text-[#3b82f6] text-[11px] font-semibold tracking-[0.15em] uppercase">Features</span>
          <h2 className="text-4xl sm:text-5xl lg:text-[3.5rem] font-extrabold mt-4 tracking-tight leading-[1.1]">
            Everything you need to{' '}
            <span className="text-gradient">find faster</span>
          </h2>
          <p className="text-[#8e8e93] text-[17px] mt-5 max-w-lg mx-auto leading-relaxed">
            A complete toolkit for searching, previewing, and managing your files.
          </p>
        </div>

        <div className="stagger-children grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {features.map((f) => (
            <FeatureCard key={f.title} feature={f} />
          ))}
        </div>
      </div>
    </section>
  )
}

function FeatureCard({ feature }: { feature: typeof features[0] }) {
  const ref = useRef<HTMLDivElement>(null)
  useReveal(ref)

  return (
    <div ref={ref} className={`group reveal p-6 rounded-2xl bg-[#111113] border ${feature.border} card-glow`}>
      <div className={`w-10 h-10 rounded-xl ${feature.bg} flex items-center justify-center mb-5 transition-transform duration-500 group-hover:scale-105`}>
        <feature.icon className={`w-[18px] h-[18px] ${feature.color}`} strokeWidth={1.8} />
      </div>
      <h3 className="text-[15px] font-bold mb-2 tracking-tight">{feature.title}</h3>
      <p className="text-[13px] text-[#8e8e93] leading-relaxed">{feature.description}</p>
    </div>
  )
}
