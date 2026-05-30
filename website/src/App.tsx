import Navbar from './components/Navbar'
import Hero from './components/Hero'
import Features from './components/Features'
import HowItWorks from './components/HowItWorks'
import DownloadCTA from './components/DownloadCTA'
import Footer from './components/Footer'

export default function App() {
  return (
    <div className="relative min-h-screen bg-background overflow-x-hidden">
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-primary/5 rounded-full blur-[120px]" />
        <div className="absolute bottom-0 right-0 w-[600px] h-[500px] bg-primary/3 rounded-full blur-[100px]" />
      </div>
      <Navbar />
      <main className="relative z-10">
        <Hero />
        <Features />
        <HowItWorks />
        <DownloadCTA />
      </main>
      <Footer />
    </div>
  )
}
