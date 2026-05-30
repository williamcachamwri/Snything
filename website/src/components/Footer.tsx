import { Github, Heart } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="border-t border-border/50 py-12 px-6">
      <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6">
        <div className="flex items-center gap-2 text-sm text-text-muted">
          <span className="font-semibold text-text">Snything</span>
          <span>&middot;</span>
          <span>Find anything, instantly</span>
        </div>

        <div className="flex items-center gap-6 text-sm text-text-muted">
          <a
            href="https://github.com/williamcachamwri/Snything"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 hover:text-text transition-colors"
          >
            <Github className="w-4 h-4" />
            GitHub
          </a>
        </div>

        <div className="flex items-center gap-1.5 text-sm text-text-muted">
          <span>Made with</span>
          <Heart className="w-3.5 h-3.5 text-rose-400 fill-rose-400" />
          <span>for macOS</span>
        </div>
      </div>
    </footer>
  )
}
