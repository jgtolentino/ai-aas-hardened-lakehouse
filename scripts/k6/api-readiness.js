import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  thresholds: {
    http_req_failed: ['rate<=0.001'],           // <= 0.1% error rate
    http_req_duration: ['p(95)<=250'],          // p95 <= 250ms overall
    'http_req_duration{name:healthz}': ['p(95)<=50'],   // healthz faster
    'http_req_duration{name:brands}': ['p(95)<=200'],   // brand lookups fast
    'http_req_duration{name:detect}': ['p(95)<=300'],   // ML inference reasonable
  },
  scenarios: {
    smoke: { 
      executor: 'constant-vus', 
      vus: 5, 
      duration: '1m',
      gracefulStop: '10s',
    },
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '30s', target: 0 },
      ],
      gracefulStop: '10s',
    }
  }
};

const BASE = __ENV.API_BASE || 'http://localhost:8080';

export default function () {
  // Health check
  let r = http.get(`${BASE}/healthz`, { 
    tags: { name: 'healthz' },
    timeout: '5s'
  });
  check(r, { 
    'health 200': (res) => res.status === 200,
    'health fast': (res) => res.timings.duration < 50
  });

  // Brand catalog
  r = http.get(`${BASE}/catalog/brands`, { 
    tags: { name: 'brands' },
    timeout: '10s'
  });
  check(r, {
    'brands 200': (res) => res.status === 200,
    'brands non-empty': (res) => {
      try {
        const data = res.json();
        return Array.isArray(data) && data.length >= 10; // At least 10 brands
      } catch (e) {
        return false;
      }
    },
    'brands has structure': (res) => {
      try {
        const data = res.json();
        return data[0] && data[0].brand_name && data[0].category;
      } catch (e) {
        return false;
      }
    }
  });

  // Brand detection
  const testCases = [
    { text: 'Kuya, may Lucky Me ba kayo?', expected: 'Lucky Me' },
    { text: 'Nescafe 3-in-1 please', expected: 'Nescafe' },
    { text: 'Bear Brand milk available?', expected: 'Bear Brand' }
  ];
  
  const testCase = testCases[Math.floor(Math.random() * testCases.length)];
  r = http.post(`${BASE}/detect`, JSON.stringify({ text: testCase.text }), {
    headers: { 'content-type': 'application/json' }, 
    tags: { name: 'detect' },
    timeout: '15s'
  });
  
  check(r, { 
    'detect 200': (res) => res.status === 200,
    'detect has brands': (res) => {
      try {
        const data = res.json();
        return data.detected_brands && Array.isArray(data.detected_brands);
      } catch (e) {
        return false;
      }
    },
    'detect accuracy': (res) => {
      try {
        const data = res.json();
        return data.detected_brands.some(b => b.brand === testCase.expected);
      } catch (e) {
        return false;
      }
    }
  });

  // Scout analytics endpoints
  r = http.get(`${BASE}/api/gold/kpis`, {
    tags: { name: 'kpis' },
    timeout: '10s'
  });
  check(r, {
    'kpis 200': (res) => res.status === 200 || res.status === 401, // Auth might be required
  });

  sleep(0.2);
}