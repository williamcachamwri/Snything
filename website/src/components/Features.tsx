import { useEffect, useRef, useState } from 'react'
import { Search, Eye, History, Zap, Command, Layers } from 'lucide-react'

const features = [
  {
    icon: Search,
    title: 'Instant Search',
    description: 'Type and see results in milliseconds. No indexing delays, no waiting.',
    color: 'from-blue-500/20 to-blue-600/5',
    accent: 'blue-400',
    border: 'border-blue-500/20',
    shadow: 'shadow-blue-500/10',
  },
  {
    icon: Eye,
    title: 'OCR Image Search',
    description: 'Search text inside screenshots, photos, and scanned documents automatically.',
    color: 'from-purple-500/20 to-purple-600/5',
    accent: 'purple-400',
    border: 'border-purple-500/20',
    shadow: 'shadow-purple-500/10',
  },
  {
    icon: History,
    title: 'Clipboard History',
    description: 'Never lose a copied item again. Browse and search your clipboard history.',
    color: 'from-emerald-500/20 to-emerald-600/5',
    accent: 'emerald-400',
    border: 'border-emerald-500/20',
    shadow: 'shadow-emerald-500/10',
  },
  {
    icon: Zap,
    title: 'Beautiful Previews',
    description: 'Preview images, videos, PDFs, and code files without leaving the app.',
    color: 'from-amber-500/20 to-amber-600/5',
    accent: 'amber-400',
    border: 'border-amber-500/20',
    shadow: 'shadow-amber-500/10',
  },
  {
    icon: Command,
    title: 'Global Hotkey',
    description: 'Summon Snything from anywhere with a customizable keyboard shortcut.',
    color: 'from-rose-500/20 to-rose-600/5',
    accent: 'rose-400',
    border: 'border-rose-500/20',
    shadow: 'shadow-rose-500/10',
  },
  {
    icon: Layers,
    title: 'Smart Rankings',
    description: 'Results ranked by relevance, recency, and frequency of access.',
    color: 'from-cyan-500/20 to-cyan-600/5',
    accent: 'cyan-400',
    border: 'border-cyan-500/20',
    shadow: 'shadow-cyan-500/10',
  },
]

function FeatureCard({ feature, index }: { feature: typeof features[0]; index: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true)
          observer.unobserve(el)
        }
      },
      { threshold: 0.15 }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return (
    <div
      ref={ref}
      className={`group relative p-7 rounded-2xl bg-surface border ${feature.border} hover:border-opacity-60 transition-all duration-500 hover:-translate-y-2 hover:shadow-xl ${feature.shadow}`}
      style={{
        opacity: isVisible ? 1 : 0,
        transform: isVisible ? 'translateY(0)' : 'translateY(30px)',
        transition: `opacity 0.6s ${index * 0.1}s cubic-bezier(0.22, 1, 0.36, 1), transform 0.6s ${index * 0.1}s cubic-bezier(0.22, 1, 0.36, 1)`,
      }}
    >
      {/* Gradient background on hover */}
      <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-100 transition-opacity duration-500`} />

      <div className="relative z-10">
        <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${feature.color} flex items-center justify-center mb-5 group-hover:scale-110 transition-transform duration-500`}>
          <feature.icon className={`w-5 h-5 text-${feature.accent}`} />
        </div>
        <h3 className="text-lg font-bold mb-2 group-hover:text-white transition-colors duration-300">{feature.title}</h3>
        <p className="text-text-muted text-sm leading-relaxed group-hover:text-white/80 transition-colors duration-300">{feature.description}</p>
      </div>
    </div>
  )
}

export default function Features() {
  const headerRef = useRef<HTMLDivElement>(null)
  const [headerVisible, setHeaderVisible] = useState(false)

  useEffect(() => {
    const el = headerRef.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setHeaderVisible(true)
          observer.unobserve(el)
        }
      },
      { threshold: 0.15 }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return (
    <section id="features" className="py-32 px-6">
      <div className="max-w-6xl mx-auto">
        <div
          ref={headerRef}
          className="text-center mb-20"
          style={{
            opacity: headerVisible ? 1 : 0,
            transform: headerVisible ? 'translateY(0)' : 'translateY(20px)',
            transition: 'opacity 0.7s ease, transform 0.7s ease',
          }}
        >
          <span className="text-primary text-sm font-semibold tracking-widest uppercase">Features</span>
          <h2 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold mt-4 tracking-tight">
            Everything you need to{' '}
            <span className="text-gradient">find faster</span>
          </h2>
          <p className="text-text-muted text-lg mt-5 max-w-xl mx-auto leading-relaxed">
            A complete toolkit for searching, previewing, and managing your files.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, i) => (
            <FeatureCard key={feature.title} feature={feature} index={i} />
          ))}
        </div>
      </div>
    </section>
  )
}
