import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './index.module.css';
import HomepageFeatures from '@site/src/components/HomepageFeatures';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className="hero hero--azure">
      <div className="container">
        <h1 className="hero__title animate-fadeInUp">
          {siteConfig.title}
        </h1>
        <p className="hero__subtitle animate-fadeInUp">
          {siteConfig.tagline}
        </p>
        <div className="flex gap-4 justify-center animate-fadeInUp">
          <Link
            className="button button--primary button--lg"
            to="/docs/intro">
            Get Started in 5 Minutes ⚡
          </Link>
          <Link
            className="button button--secondary button--lg"
            to="/playground">
            Try SQL Playground 💻
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title} - AI-Powered Data Warehouse`}
      description="Scout Analytics Hub - Enterprise Data Platform for Philippine Retail Intelligence">
      <HomepageHeader />
      <main>
        <HomepageFeatures />
      </main>
    </Layout>
  );
}