import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import Dashboard from '@/pages/App/Dashboard'

// Mock Inertia
vi.mock('@inertiajs/react', () => ({
  Link: ({ children, href }) => <a href={href}>{children}</a>,
  usePage: () => ({
    props: {
      recent_projects: [
        {
          id: 1,
          name: 'Test Project',
          domain: 'https://test.com',
          keywords_count: 10,
          articles_count: 5,
          created_at: '2024-01-01T00:00:00.000Z'
        }
      ],
      recent_articles: [
        {
          id: 1,
          title: 'Test Article',
          status: 'completed',
          word_count: 2000,
          keyword: 'test keyword',
          project_id: 1,
          project_name: 'Test Project',
          created_at: '2024-01-01T00:00:00.000Z'
        }
      ],
      stats: {
        total_projects: 1,
        total_keywords: 10,
        total_articles: 5,
        credits_remaining: 3
      },
      routes: {
        app: '/app',
        projects: '/projects',
        new_project: '/projects/new',
        pricing: '/pricing'
      },
      auth: {
        user: {
          id: 1,
          email_address: 'test@example.com',
          first_name: 'Test',
          credits: 3,
          has_credits: true
        }
      }
    }
  }),
  router: {
    reload: vi.fn()
  }
}))

describe('Dashboard', () => {
  it('renders the dashboard title', () => {
    render(<Dashboard />)
    expect(screen.getByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()
  })

  it('displays user stats correctly', () => {
    render(<Dashboard />)

    // Check stats are displayed
    expect(screen.getByText('Projects')).toBeInTheDocument()
    expect(screen.getByText('Keywords')).toBeInTheDocument()
    expect(screen.getByText('Articles')).toBeInTheDocument()
    expect(screen.getByText('Credits')).toBeInTheDocument()

    // Check stat values
    expect(screen.getByText('1')).toBeInTheDocument() // total_projects
    expect(screen.getByText('10')).toBeInTheDocument() // total_keywords
    expect(screen.getByText('5')).toBeInTheDocument() // total_articles
    expect(screen.getByText('3')).toBeInTheDocument() // credits_remaining
  })

  it('displays recent projects', () => {
    render(<Dashboard />)

    expect(screen.getByText('Recent Projects')).toBeInTheDocument()
    expect(screen.getByText('Test Project')).toBeInTheDocument()
    expect(screen.getByText('https://test.com')).toBeInTheDocument()
  })

  it('displays recent articles', () => {
    render(<Dashboard />)

    expect(screen.getByText('Recent Articles')).toBeInTheDocument()
    expect(screen.getByText('Test Article')).toBeInTheDocument()
    expect(screen.getByText(/test keyword/)).toBeInTheDocument()
  })

  it('shows New Project button', () => {
    render(<Dashboard />)

    const buttons = screen.getAllByText('New Project')
    expect(buttons.length).toBeGreaterThan(0)
  })
})
