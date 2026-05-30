import { useEffect, useState, useRef } from 'react'
import { Search, ArrowRight, FileText, Image, Video, Music, Code2 } from 'lucide-react'

const demoFiles = [
  { name: 'Resume_2024.pdf', icon: FileText, type: 'PDF', size: '2.4 MB' },
  { name: 'Screenshot_001.png', icon: Image, type: 'PNG', size: '1.8 MB' },
  { name: 'main.swift', icon: Code2, type: 'Swift', size: '12 KB' },
  { name: 'Design_Mockup.fig', icon: Image, type: 'Figma', size: '45 MB' },
  { name: 'Meeting_Recording.mov', icon: Video, type: 'MOV', size: '156 MB' },
  { name: 'Podcast_Ep12.mp3', icon: Music, type: 'MP3', size: '28 MB' },
]

const queries = ['resum', 'screenshot', 'main.sw', 'design', 'meeting', 'podcast']

export default function Hero() {
  const [query, setQuery] = useState('')
  const [qIdx, setQIdx] = useState(0)
  const [phase, setPhase] = useState<'typing' | 'deleting' | 'idle'>('idle')
  const [showResults, setShowResults] = useState(false)
  const tRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    const full = queries[qIdx]
    if (phase === 'idle') {
      tRef.current = setTimeout(() => { setPhase('typing'); setShowResults(false) }, 600)
      return
    }
    if (phase === 'typing') {
      if (query.length < full.length) {
        tRef.current = setTimeout(() => setQuery(full.slice(0, query.length + 1)), 70)
      } else {
        setShowResults(true)
        tRef.current = setTimeout(() => setPhase('deleting'), 1800)
      }
      return
    }
    if (phase === 'deleting') {
      if (query.length > 0) {
        tRef.current = setTimeout(() => setQuery(query.slice(0, -1)), 35)
      } else {
        setShowResults(false)
        tRef.current = setTimeout(() => { setQIdx((i) => (i + 1) % queries.length); setPhase('idle') }, 400)
      }
      return
    }
    return () => { if (tRef.current) clearTimeout(tRef.current) }
  }, [query, qIdx, phase])

  const filtered = demoFiles.filter(f => f.name.toLowerCase().includes(query.toLowerCase()))

  const highlight = (text: string, q: string) => {
    if (!q) return text
    const parts = text.split(new RegExp(`(${q})`, 'gi'))
    return parts.map((part, i) =>
      part.toLowerCase() === q.toLowerCase()
        ? <span key={i} className="text-[#3b82f6] font-semibold">{part}</span>
        : <span key={i}>{part}</span>
    )
  }

  return (
    <section className="relative min-h-screen flex items-center justify-center pt-24 pb-20 px-6">
      <div className="absolute top-[18%] left-[8%] w-3 h-3 rounded-full bg-[#3b82f6]/20 blur-[2px]" style={{ animation: 'float 7s ease-in-out infinite' }} />
      <div className="absolute top-[55%] right-[10%] w-2 h-2 rounded-full bg-[#6366f1]/20 blur-[1px]" style={{ animation: 'float 9s ease-in-out infinite 1s' }} />

      <div className="max-w-4xl mx-auto w-full text-center">
        <div className="anim-fade-up anim-delay-1 inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[#3b82f6]/20 bg-[#3b82f6]/5 text-[#3b82f6] text-[11px] font-medium tracking-wide uppercase mb-10">
          <span className="w-1.5 h-1.5 rounded-full bg-[#3b82f6] animate-pulse" />
          macOS Search, Reinvented
        </div>

        <h1 className="anim-fade-up anim-delay-2 text-5xl sm:text-6xl lg:text-7xl font-extrabold tracking-tight leading-[1.08] mb-7">
          Find anything,{' '}
          <span className="text-gradient">instantly</span>
        </h1>

        <p className="anim-fade-up anim-delay-3 text-[17px] sm:text-lg text-[#8e8e93] max-w-xl mx-auto mb-12 leading-relaxed">
          Lightning-fast file search with OCR, clipboard history, and beautiful previews. Built natively for macOS.
        </p>

        <div className="anim-fade-up anim-delay-4 flex flex-col sm:flex-row items-center justify-center gap-3 mb-20">
          <a href="#download" className="group flex items-center gap-2.5 px-7 py-3 text-[14px] font-semibold text-white bg-[#3b82f6] hover:bg-[#2563eb] rounded-full transition-all duration-300 hover:shadow-[0_0_30px_-8px_rgba(59,130,246,0.45)]">
            Download Free
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-0.5" />
          </a>
          <a href="#features" className="px-7 py-3 text-[14px] font-medium text-[#8e8e93] hover:text-[#f1f1f3] rounded-full border border-[#2a2a2e] hover:border-[#3b82f6]/30 transition-all duration-300">
            Learn more
          </a>
        </div>

        <div className="anim-scale-in anim-delay-6 max-w-xl mx-auto text-left">
          <div className="bg-[#111113]/40 backdrop-blur-xl border border-[#1f1f23]/40 rounded-2xl p-1.5 shadow-2xl shadow-black/40">
            <div className="flex items-center gap-3 px-4 py-3 bg-[#0d0d10] rounded-xl border border-[#1f1f23]/60">
              <Search className="w-[18px] h-[18px] text-[#8e8e93] shrink-0" />
              <div className="flex-1 font-mono text-[15px] text-[#f1f1f3] tracking-tight">
                <span>{query}</span>
                <span className="cursor-blink text-[#3b82f6] ml-px">|</span>
              </div>
              <div className="hidden sm:flex items-center gap-1 px-2 py-1 rounded-md bg-[#1a1a1e] border border-[#2a2a2e] text-[11px] text-[#8e8e93] font-mono">
                <span className="text-[10px]">&#8984;</span>
                <span>Space</span>
              </div>
            </div>

            <div className={`transition-all duration-500 ease-out overflow-hidden ${showResults && query.length > 0 ? 'max-h-[280px] opacity-100 mt-1.5' : 'max-h-0 opacity-0'}`}>
              {filtered.length > 0 ? (
                filtered.slice(0, 4).map((file, i) => (
                  <div key={file.name}
                    className={`flex items-center gap-3 px-4 py-2.5 mx-0.5 rounded-xl transition-colors duration-200 cursor-default ${i === 0 ? 'bg-[#3b82f6]/8' : 'hover:bg-[#1a1a1e]'}`}
                    style={{ animation: showResults ? `result-enter 0.35s ${i * 0.05}s ease forwards` : 'none', opacity: 0 }}
                  >
                    <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${i === 0 ? 'bg-[#3b82f6]/15' : 'bg-[#1a1a1e]'}`}>
                      <file.icon className={`w-3.5 h-3.5 ${i === 0 ? 'text-[#3b82f6]' : 'text-[#8e8e93]'}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-[13px] font-medium truncate">{highlight(file.name, query)}</div>
                      <div className="text-[11px] text-[#8e8e93]">{file.type} · {file.size}</div>
                    </div>
                    {i === 0 && (
                      <span className="text-[11px] font-medium text-[#3b82f6] px-2 py-0.5 bg-[#3b82f6]/10 rounded-md shrink-0">Enter</span>
                    )}
                  </div>
                ))
              ) : (
                <div className="px-4 py-6 text-center text-[13px] text-[#8e8e93]">No results</div>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
