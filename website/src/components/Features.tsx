import { motion } from 'framer-motion'
import { Search, Eye, History, Zap, Command, Layers } from 'lucide-react'
import { useInView } from '../hooks/useInView'

const features = [
  {
    icon: Search,
    title: 'Instant Search',
    description: 'Type and see results in milliseconds. No indexing delays, no waiting.',
    color: 'from-blue-500/20 to-blue-600/10',
    iconColor: 'text-blue-400',
  },
  {
    icon: Eye,
    title: 'OCR Image Search',
    description: 'Search text inside screenshots, photos, and scanned documents automatically.',
    color: 'from-purple-500/20 to-purple-600/10',
    iconColor: 'text-purple-400',
  },
  {
    icon: History,
    title: 'Clipboard History',
    description: 'Never lose a copied item again. Browse and search your clipboard history.',
    color: 'from-emerald-500/20 to-emerald-600/10',
    iconColor: 'text-emerald-400',
  },
  {
    icon: Zap,
    title: 'Beautiful Previews',
    description: 'Preview images, videos, PDFs, and code files without leaving the app.',
    color: 'from-amber-500/20 to-amber-600/10',
    iconColor: 'text-amber-400',
  },
  {
    icon: Command,
    title: 'Global Hotkey',
    description: 'Summon Snything from anywhere with a customizable keyboard shortcut.',
    color: 'from-rose-500/20 to-rose-600/10',
    iconColor: 'text-rose-400',
  },
  {
    icon: Layers,
    title: 'Smart Rankings',
    description: 'Results ranked by relevance, recency, and frequency of access.',
    color: 'from-cyan-500/20 to-cyan-600/10',
    iconColor: 'text-cyan-400',
  },
]

const container = {
  hidden: {},
  show: {
    transition: { staggerChildren: 0.1 },
  },
}

const item = {
  hidden: { opacity: 0, y: 30 },
  show: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } },
}

export default function Features() {
  const { ref, isInView } = useInView(0.15)

  return (
    <section id="features" className="py-32 px-6" ref={ref}>
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.7 }}
          className="text-center mb-20"
        >
          <span className="text-primary text-sm font-medium tracking-wide uppercase">Features</span>
          <h2 className="text-4xl sm:text-5xl font-bold mt-3 tracking-tight">
            Everything you need to{' '}
            <span className="text-gradient">find faster</span>
          </h2>
          <p className="text-text-muted text-lg mt-4 max-w-xl mx-auto">
            A complete toolkit for searching, previewing, and managing your files.
          </p>
        </motion.div>

        <motion.div
          variants={container}
          initial="hidden"
          animate={isInView ? 'show' : 'hidden'}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={item}
              className="group relative p-6 rounded-2xl bg-surface border border-border/50 hover:border-primary/30 transition-all duration-500 hover:-translate-y-1"
            >
              <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-100 transition-opacity duration-500`} />
              <div className="relative">
                <div className={`w-11 h-11 rounded-xl bg-surface-light flex items-center justify-center mb-5 group-hover:scale-110 transition-transform duration-300`}>
                  <feature.icon className={`w-5 h-5 ${feature.iconColor}`} />
                </div>
                <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
                <p className="text-text-muted text-sm leading-relaxed">{feature.description}</p>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
