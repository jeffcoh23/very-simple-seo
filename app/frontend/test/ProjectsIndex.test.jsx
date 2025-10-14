import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import ProjectsIndex from '@/pages/App/Projects/Index'

// Mock Inertia
vi.mock('@inertiajs/react', () => ({
  Link: ({ children, href }) => <a href={href}>{children}</a>,
  usePage: () => ({
    props: {
      projects: [
        {
          id: 1,
          name: 'Test Project 1',
          domain: 'https://test1.com',
          niche: 'SaaS',
          keywords_count: 10,
          articles_count: 5,
          competitors_count: 3
        },
        {
          id: 2,
          name: 'Test Project 2',
          domain: 'https://test2.com',
          niche: 'E-commerce',
          keywords_count: 20,
          articles_count: 8,
          competitors_count: 5
        }
      ],
      routes: {
        projects: '/projects',
        new_project: '/projects/new'
      }
    }
  })
}))

describe('ProjectsIndex', () => {
  it('renders the projects page title', () => {
    render(<ProjectsIndex />)
    expect(screen.getByRole('heading', { name: 'Projects' })).toBeInTheDocument()
    expect(screen.getByText('Manage your SEO content projects')).toBeInTheDocument()
  })

  it('displays all projects', () => {
    render(<ProjectsIndex />)

    expect(screen.getByText('Test Project 1')).toBeInTheDocument()
    expect(screen.getByText('Test Project 2')).toBeInTheDocument()
    expect(screen.getByText('https://test1.com')).toBeInTheDocument()
    expect(screen.getByText('https://test2.com')).toBeInTheDocument()
  })

  it('displays project statistics', () => {
    render(<ProjectsIndex />)

    // Project 1 stats
    expect(screen.getByText('10')).toBeInTheDocument() // keywords
    expect(screen.getByText('5')).toBeInTheDocument() // articles
    expect(screen.getByText('3')).toBeInTheDocument() // competitors

    // Project 2 stats
    expect(screen.getByText('20')).toBeInTheDocument()
    expect(screen.getByText('8')).toBeInTheDocument()
  })

  it('displays niche badges', () => {
    render(<ProjectsIndex />)

    expect(screen.getByText('SaaS')).toBeInTheDocument()
    expect(screen.getByText('E-commerce')).toBeInTheDocument()
  })

  it('has New Project button', () => {
    render(<ProjectsIndex />)

    const newProjectButtons = screen.getAllByText('New Project')
    expect(newProjectButtons.length).toBeGreaterThan(0)
  })

  it('has View Project buttons', () => {
    render(<ProjectsIndex />)

    const viewButtons = screen.getAllByText('View Project')
    expect(viewButtons).toHaveLength(2)
  })
})

describe('ProjectsIndex - Empty State', () => {
  it('shows empty state when no projects', () => {
    // Override mock for empty state
    vi.mock('@inertiajs/react', () => ({
      Link: ({ children, href }) => <a href={href}>{children}</a>,
      usePage: () => ({
        props: {
          projects: [],
          routes: {
            projects: '/projects',
            new_project: '/projects/new'
          }
        }
      })
    }))

    render(<ProjectsIndex />)

    expect(screen.getByText('No projects yet')).toBeInTheDocument()
    expect(screen.getByText(/Get started by creating your first project/)).toBeInTheDocument()
  })
})
