import { useState, useEffect } from 'react'
import { Search, Menu, X } from 'lucide-react'

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const links = [
    { label: 'Features', href: '#features' },
    { label: 'How it works', href: '#how-it-works' },
    { label: 'Download', href: '#download' },
  ]

  return (
    <header className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${scrolled ? 'bg-[#111113]/70 backdrop-blur-2xl border-b border-[#1f1f23]/40' : 'bg-transparent'}`}>
      <div className="max-w-5xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2.5 group">
          <div className="w-7 h-7 rounded-md bg-[#3b82f6] flex items-center justify-center transition-transform duration-300 group-hover:scale-105">
            <Search className="w-3.5 h-3.5 text-white" />
          </div>
          <span className="text-[15px] font-semibold tracking-tight">Snything</span>
        </a>

        <nav className="hidden md:flex items-center gap-8">
          {links.map((link) => (
            <a key={link.label} href={link.href} className="relative text-[13px] text-[#8e8e93] hover:text-[#f1f1f3] transition-colors duration-300 group py-1">
              {link.label}
              <span className="absolute bottom-0 left-0 w-0 h-[1.5px] bg-[#3b82f6] rounded-full group-hover:w-full transition-all duration-300 ease-out" />
            </a>
          ))}
        </nav>

        <div className="hidden md:flex items-center gap-3">
          <a href="#download" className="px-5 py-2 text-[13px] font-medium text-white bg-[#3b82f6] hover:bg-[#2563eb] rounded-full transition-all duration-300 hover:shadow-[0_0_20px_-5px_rgba(59,130,246,0.4)]">
            Download
          </a>
        </div>

        <button onClick={() => setMenuOpen(!menuOpen)} className="md:hidden p-2 rounded-lg hover:bg-[#1a1a1e] transition-colors">
          {menuOpen ? <X className="w-4 h-4" /> : <Menu className="w-4 h-4" />}
        </button>
      </div>

      {menuOpen && (
        <div className="md:hidden bg-[#111113]/70 backdrop-blur-2xl border-t border-[#1f1f23]/40">
          <div className="px-6 py-4 flex flex-col gap-1">
            {links.map((link) => (
              <a key={link.label} href={link.href} onClick={() => setMenuOpen(false)} className="px-4 py-3 text-sm text-[#8e8e93] hover:text-[#f1f1f3] hover:bg-[#1a1a1e] rounded-lg transition-colors">{link.label}</a>
            ))}
            <a href="#download" onClick={() => setMenuOpen(false)} className="mt-2 px-4 py-3 text-sm font-medium text-center text-white bg-[#3b82f6] rounded-full">Download</a>
          </div>
        </div>
      )}
    </header>
  )
}
