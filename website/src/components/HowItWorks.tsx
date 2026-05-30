import { motion } from 'framer-motion'
import { useInView } from '../hooks/useInView'
import { Command, Type, Eye, ArrowRight } from 'lucide-react'

const steps = [
  {
    number: '01',
    title: 'Summon',
    description: 'Press your global hotkey from anywhere on macOS. Snything appears instantly over any app.',
    icon: Command,
  },
  {
    number: '02',
    title: 'Type',
    description: 'Start typing a filename, OCR text, or even a math expression. Results update in real-time.',
    icon: Type,
  },
  {
    number: '03',
    title: 'Preview & Open',
    description: 'Arrow through results, preview files without leaving, and press Enter to open.',
    icon: Eye,
  },
]

export default function HowItWorks() {
  const { ref, isInView } = useInView(0.15)

  return (
    <section id="how-it-works" className="py-32 px-6 bg-surface/50" ref={ref}>
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.7 }}
          className="text-center mb-20"
        >
          <span className="text-primary text-sm font-medium tracking-wide uppercase">How it works</span>
          <h2 className="text-4xl sm:text-5xl font-bold mt-3 tracking-tight">
            Three steps to{' '}
            <span className="text-gradient">find anything</span>
          </h2>
        </motion.div>

        <div className="relative">
          {/* Connecting line */}
          <div className="hidden lg:block absolute top-1/2 left-0 right-0 h-px bg-gradient-to-r from-transparent via-border to-transparent" />

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 lg:gap-12">
            {steps.map((step, i) => (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, y: 40 }}
                animate={isInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.7, delay: i * 0.15, ease: [0.22, 1, 0.36, 1] }}
                className="relative"
              >
                <div className="flex flex-col items-center text-center">
                  <div className="relative mb-8">
                    <div className="w-16 h-16 rounded-2xl bg-surface border border-border flex items-center justify-center">
                      <step.icon className="w-6 h-6 text-primary" />
                    </div>
                    <span className="absolute -top-2 -right-2 w-7 h-7 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center">
                      {step.number}
                    </span>
                  </div>

                  <h3 className="text-xl font-semibold mb-3">{step.title}</h3>
                  <p className="text-text-muted text-sm leading-relaxed max-w-xs">
                    {step.description}
                  </p>
                </div>

                {i < steps.length - 1 && (
                  <div className="hidden lg:flex absolute top-8 left-full w-12 items-center justify-center">
                    <ArrowRight className="w-5 h-5 text-border" />
                  </div>
                )}
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
