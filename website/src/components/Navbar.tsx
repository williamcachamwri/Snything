import { useState, useEffect } from 'react'
import { Search, Menu, X, Download } from 'lucide-react'

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40)
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const links = [
    { label: 'Features', href: '#features' },
    { label: 'How it works', href: '#how-it-works' },
    { label: 'Download', href: '#download' },
  ]

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
        scrolled ? 'glass shadow-lg shadow-black/20' : 'bg-transparent'
      }`}
      style={{ animation: 'slide-up 0.8s cubic-bezier(0.22, 1, 0.36, 1) forwards' }}
    >
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-primary flex items-center justify-center group-hover:shadow-lg group-hover:shadow-primary/30 transition-all duration-300">
            <Search className="w-4 h-4 text-white" />
          </div>
          <span className="text-lg font-bold tracking-tight">Snything</span>
        </a>

        <nav className="hidden md:flex items-center gap-1">
          {links.map((link) => (
            <a
              key={link.label}
              href={link.href}
              className="relative px-4 py-2 text-sm text-text-muted hover:text-text rounded-full transition-all duration-300 group"
            >
              {link.label}
              <span className="absolute bottom-1 left-1/2 -translate-x-1/2 w-0 h-0.5 bg-primary rounded-full group-hover:w-6 transition-all duration-300" />
            </a>
          ))}
        </nav>

        <div className="hidden md:flex items-center gap-3">
          <a
            href="#download"
            className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-primary to-blue-500 hover:from-blue-500 hover:to-primary text-white text-sm font-medium rounded-full transition-all duration-500 shadow-lg shadow-primary/25 hover:shadow-primary/40 hover:scale-105"
          >
            <Download className="w-4 h-4" />
            Download
          </a>
        </div>

        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="md:hidden p-2 rounded-lg hover:bg-surface-light transition-colors"
        >
          {menuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
        </button>
      </div>

      {menuOpen && (
        <div 
          className="md:hidden glass border-t border-border/50 overflow-hidden"
          style={{ animation: 'slide-up 0.3s ease forwards' }}
        >
          <div className="px-6 py-4 flex flex-col gap-2">
            {links.map((link) => (
              <a
                key={link.label}
                href={link.href}
                onClick={() => setMenuOpen(false)}
                className="px-4 py-3 text-sm text-text-muted hover:text-text hover:bg-surface-light rounded-lg transition-colors"
              >
                {link.label}
              </a>
            ))}
            <a
              href="#download"
              onClick={() => setMenuOpen(false)}
              className="mt-2 flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-primary to-blue-500 text-white text-sm font-medium rounded-full"
            >
              <Download className="w-4 h-4" />
              Download
            </a>
          </div>
        </div>
      )}
    </header>
  )
}
