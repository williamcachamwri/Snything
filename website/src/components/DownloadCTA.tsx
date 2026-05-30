import { motion } from 'framer-motion'
import { useInView } from '../hooks/useInView'
import { Download, Apple, Check, ArrowRight } from 'lucide-react'

const requirements = [
  'macOS 14.0 or later',
  'Apple Silicon or Intel',
  'Free forever',
  'Open source',
]

export default function DownloadCTA() {
  const { ref, isInView } = useInView(0.2)

  return (
    <section id="download" className="py-32 px-6" ref={ref}>
      <motion.div
        initial={{ opacity: 0, y: 40 }}
        animate={isInView ? { opacity: 1, y: 0 } : {}}
        transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
        className="max-w-4xl mx-auto"
      >
        <div className="relative overflow-hidden rounded-3xl glass p-8 sm:p-12 lg:p-16 text-center">
          {/* Background glow */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[500px] h-[300px] bg-primary/10 rounded-full blur-[100px] pointer-events-none" />

          <div className="relative">
            <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-primary/10 mb-6">
              <Download className="w-6 h-6 text-primary" />
            </div>

            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight mb-4">
              Ready to find anything,{' '}
              <span className="text-gradient">instantly?</span>
            </h2>

            <p className="text-text-muted text-lg max-w-lg mx-auto mb-8">
              Download Snything for free and never waste time searching for files again.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-10">
              <a
                href="https://github.com/williamcachamwri/Snything/releases/latest"
                target="_blank"
                rel="noopener noreferrer"
                className="group flex items-center gap-3 px-8 py-4 bg-primary hover:bg-primary-glow text-white font-semibold rounded-full transition-all duration-300 glow-strong"
              >
                <Apple className="w-5 h-5" />
                Download for macOS
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </a>
              <a
                href="https://github.com/williamcachamwri/Snything"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 px-6 py-4 text-text-muted hover:text-text font-medium rounded-full border border-border hover:border-primary/30 transition-all duration-300"
              >
                View on GitHub
              </a>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2">
              {requirements.map((req) => (
                <div key={req} className="flex items-center gap-2 text-sm text-text-muted">
                  <Check className="w-4 h-4 text-primary" />
                  {req}
                </div>
              ))}
            </div>
          </div>
        </div>
      </motion.div>
    </section>
  )
}
