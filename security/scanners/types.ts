export interface SecurityScanResult {
  scanId: string;
  scanner: string;
  scanType: 'sast' | 'dast' | 'dependency' | 'container' | 'secrets' | 'iac';
  startTime: Date;
  endTime: Date;
  status: 'success' | 'failure' | 'partial';
  findings: SecurityFinding[];
  summary: {
    total: number;
    critical: number;
    high: number;
    medium: number;
    low: number;
    info: number;
  };
  metadata?: Record<string, any>;
}

export interface SecurityFinding {
  id: string;
  type: string;
  severity: 'critical' | 'high' | 'medium' | 'low' | 'info';
  title: string;
  description: string;
  location?: {
    file?: string;
    line?: number;
    column?: number;
    endLine?: number;
    endColumn?: number;
  };
  cve?: string;
  cwe?: string;
  owasp?: string;
  remediation?: string;
  references?: string[];
  falsePositive?: boolean;
  suppressionRule?: string;
}

export interface ScannerConfig {
  name: string;
  type: 'sast' | 'dast' | 'dependency' | 'container' | 'secrets' | 'iac';
  enabled: boolean;
  command?: string;
  docker?: {
    image: string;
    volumes?: string[];
    environment?: Record<string, string>;
  };
  options?: Record<string, any>;
  timeout?: number;
  severity?: string[];
  ignorePatterns?: string[];
  customRules?: string[];
}

export interface ScanRequest {
  id: string;
  target: string;
  scanners: string[];
  options?: {
    branch?: string;
    commit?: string;
    pullRequest?: number;
    excludePaths?: string[];
    includePaths?: string[];
    severityThreshold?: 'critical' | 'high' | 'medium' | 'low';
    failOnFindings?: boolean;
  };
  metadata?: Record<string, any>;
}

export interface Scanner {
  name: string;
  type: ScannerConfig['type'];
  scan(target: string, options?: any): Promise<SecurityScanResult>;
  isAvailable(): Promise<boolean>;
  getVersion(): Promise<string>;
}

export interface SecurityPolicy {
  id: string;
  name: string;
  description: string;
  rules: PolicyRule[];
  enforcement: 'block' | 'warn' | 'monitor';
  exceptions?: PolicyException[];
}

export interface PolicyRule {
  id: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
  pattern?: string;
  cwe?: string[];
  owasp?: string[];
  message: string;
  remediation: string;
}

export interface PolicyException {
  ruleId: string;
  path?: string;
  reason: string;
  expiresAt?: Date;
  approvedBy?: string;
}

export interface ComplianceReport {
  framework: 'owasp' | 'cis' | 'nist' | 'pci' | 'hipaa' | 'gdpr';
  version: string;
  scanDate: Date;
  controls: ComplianceControl[];
  summary: {
    total: number;
    passed: number;
    failed: number;
    notApplicable: number;
  };
}

export interface ComplianceControl {
  id: string;
  title: string;
  description: string;
  status: 'passed' | 'failed' | 'not_applicable';
  findings?: SecurityFinding[];
  evidence?: string[];
}