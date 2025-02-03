import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { expect, describe, it } from 'vitest';
import Home from '../pages/Home';

describe('Home', () => {
  const renderHome = () => {
    render(
      <BrowserRouter>
        <Home />
      </BrowserRouter>
    );
  };

  it('renders the main heading', () => {
    renderHome();
    expect(screen.getByText('Group gifting, simplified')).toBeInTheDocument();
  });

  it('renders the get started button', () => {
    renderHome();
    expect(screen.getByText('Get started')).toBeInTheDocument();
  });

  it('renders the login link', () => {
    renderHome();
    expect(screen.getByText(/Already have an account?/)).toBeInTheDocument();
  });

  it('renders feature sections', () => {
    renderHome();
    expect(screen.getByText('Create Gift Projects')).toBeInTheDocument();
    expect(screen.getByText('Vote Together')).toBeInTheDocument();
  });

  it('renders the CTA section', () => {
    renderHome();
    expect(screen.getByText('Ready to start gifting together?')).toBeInTheDocument();
    expect(screen.getByText('Get started for free')).toBeInTheDocument();
  });
});