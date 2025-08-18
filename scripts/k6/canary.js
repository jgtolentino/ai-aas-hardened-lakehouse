import http from 'k6/http'; import { check, sleep } from 'k6';
export const options = { thresholds: { http_req_failed: ['rate<=0.002'], http_req_duration: ['p(95)<=300'] }, vus: 10, duration: '1m' };
const BASE = __ENV.API_BASE; export default () => { const r = http.get(`${BASE}/healthz`); check(r,{ok:(res)=>res.status===200}); sleep(0.1); };