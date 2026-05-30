import { Github, Heart } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="border-t border-[#1f1f23]/50 py-10 px-6">
      <div className="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2 text-[13px] text-[#8e8e93]">
          <span className="font-bold text-[#f1f1f3]">Snything</span>
          <span className="text-[#2a2a2e]">|</span>
          <span>Find anything, instantly</span>
        </div>

        <a
          href="https://github.com/williamcachamwri/Snything"
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-2 text-[13px] text-[#8e8e93] hover:text-[#f1f1f3] transition-colors duration-300"
        >
          <Github className="w-3.5 h-3.5" />
          GitHub
        </a>

        <div className="flex items-center gap-1.5 text-[13px] text-[#8e8e93]">
          <span>Made with</span>
          <Heart className="w-3 h-3 text-rose-400 fill-rose-400" />
          <span>for macOS</span>
        </div>
      </div>
    </footer>
  )
}
