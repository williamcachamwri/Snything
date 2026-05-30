import { Github, Heart, Twitter } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="border-t border-border/50 py-12 px-6">
      <div className="max-w-6xl mx-auto">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-2 text-sm text-text-muted">
            <span className="font-bold text-text text-base">Snything</span>
            <span className="text-border">|</span>
            <span>Find anything, instantly</span>
          </div>

          <div className="flex items-center gap-6 text-sm">
            <a
              href="https://github.com/williamcachamwri/Snything"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-text-muted hover:text-text transition-colors duration-300"
            >
              <Github className="w-4 h-4" />
              GitHub
            </a>
            <a
              href="#"
              className="flex items-center gap-2 text-text-muted hover:text-text transition-colors duration-300"
            >
              <Twitter className="w-4 h-4" />
              Twitter
            </a>
          </div>

          <div className="flex items-center gap-1.5 text-sm text-text-muted">
            <span>Made with</span>
            <Heart className="w-3.5 h-3.5 text-rose-400 fill-rose-400 animate-pulse" />
            <span>for macOS</span>
          </div>
        </div>
      </div>
    </footer>
  )
}
