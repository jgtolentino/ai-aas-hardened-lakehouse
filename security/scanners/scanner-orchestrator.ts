import { EventEmitter } from 'events';
import { TrivyScanner } from './trivy-scanner';
import { SemgrepScanner } from './semgrep-scanner';
import { TruffleHogScanner } from './trufflehog-scanner';
import type { 
  Scanner, 
  ScanRequest, 
  SecurityScanResult, 
  SecurityFinding,
  ScannerConfig 
} from './types';

export interface OrchestratorConfig {
  parallel?: boolean;
  maxConcurrency?: number;
  scanners?: string[];
  failFast?: boolean;
}

export interface ScanSummary {
  requestId: string;
  target: string;
  startTime: Date;
  endTime: Date;
  totalFindings: number;
  findingsBySeverity: Record<string, number>;
  findingsByScanner: Record<string, number>;
  failedScanners: string[];
  results: SecurityScanResult[];
}

export class ScannerOrchestrator extends EventEmitter {
  private scanners: Map<string, Scanner> = new Map();
  private config: OrchestratorConfig;
  private activeScanCount = 0;

  constructor(config: OrchestratorConfig = {}) {
    super();
    this.config = {
      parallel: true,
      maxConcurrency: 3,
      failFast: false,
      ...config
    };

    this.initializeScanners();
  }

  private initializeScanners(): void {
    // Initialize built-in scanners
    const availableScanners = [
      new TrivyScanner(),
      new SemgrepScanner(),
      new TruffleHogScanner()
    ];

    for (const scanner of availableScanners) {
      if (!this.config.scanners || this.config.scanners.includes(scanner.name)) {
        this.scanners.set(scanner.name, scanner);
        this.emit('scanner:registered', scanner.name);
      }
    }
  }

  async scan(request: ScanRequest): Promise<ScanSummary> {
    const startTime = new Date();
    this.emit('scan:start', request);

    // Validate request
    if (!request.target) {
      throw new Error('Target is required for scanning');
    }

    // Determine which scanners to use
    const scannersToUse = this.selectScanners(request);
    
    if (scannersToUse.length === 0) {
      throw new Error('No scanners available for the request');
    }

    // Execute scans
    const results = await this.executeScanners(scannersToUse, request);
    
    // Create summary
    const summary = this.createSummary(request, results, startTime);
    
    this.emit('scan:complete', summary);
    return summary;
  }

  private selectScanners(request: ScanRequest): Scanner[] {
    const selectedScanners: Scanner[] = [];

    // If specific scanners requested, use those
    if (request.scanners && request.scanners.length > 0) {
      for (const scannerName of request.scanners) {
        const scanner = this.scanners.get(scannerName);
        if (scanner) {
          selectedScanners.push(scanner);
        } else {
          this.emit('scanner:notfound', scannerName);
        }
      }
    } else {
      // Auto-select based on target type
      selectedScanners.push(...this.autoSelectScanners(request.target));
    }

    return selectedScanners;
  }

  private autoSelectScanners(target: string): Scanner[] {
    const selected: Scanner[] = [];

    // Always run secrets scanner
    const secretsScanner = this.scanners.get('trufflehog');
    if (secretsScanner) {
      selected.push(secretsScanner);
    }

    // For code repositories, add SAST
    const semgrep = this.scanners.get('semgrep');
    if (semgrep && this.isCodeRepository(target)) {
      selected.push(semgrep);
    }

    // For anything that might have dependencies or containers
    const trivy = this.scanners.get('trivy');
    if (trivy) {
      selected.push(trivy);
    }

    return selected;
  }

  private isCodeRepository(target: string): boolean {
    // Simple heuristic - can be improved
    return !target.includes(':') || 
           target.endsWith('.git') || 
           target.includes('github.com');
  }

  private async executeScanners(
    scanners: Scanner[], 
    request: ScanRequest
  ): Promise<SecurityScanResult[]> {
    if (this.config.parallel) {
      return this.executeParallel(scanners, request);
    } else {
      return this.executeSequential(scanners, request);
    }
  }

  private async executeParallel(
    scanners: Scanner[], 
    request: ScanRequest
  ): Promise<SecurityScanResult[]> {
    const results: SecurityScanResult[] = [];
    const concurrency = this.config.maxConcurrency || 3;
    
    // Process scanners in batches
    for (let i = 0; i < scanners.length; i += concurrency) {
      const batch = scanners.slice(i, i + concurrency);
      const batchPromises = batch.map(scanner => 
        this.executeSingleScanner(scanner, request)
      );
      
      if (this.config.failFast) {
        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults.filter(r => r !== null) as SecurityScanResult[]);
        
        // Check for critical findings
        if (this.hasCriticalFindings(results)) {
          this.emit('scan:critical', results);
          break;
        }
      } else {
        const batchResults = await Promise.allSettled(batchPromises);
        for (const result of batchResults) {
          if (result.status === 'fulfilled' && result.value) {
            results.push(result.value);
          }
        }
      }
    }
    
    return results;
  }

  private async executeSequential(
    scanners: Scanner[], 
    request: ScanRequest
  ): Promise<SecurityScanResult[]> {
    const results: SecurityScanResult[] = [];
    
    for (const scanner of scanners) {
      try {
        const result = await this.executeSingleScanner(scanner, request);
        if (result) {
          results.push(result);
          
          // Check for critical findings in fail-fast mode
          if (this.config.failFast && this.hasCriticalFindings([result])) {
            this.emit('scan:critical', result);
            break;
          }
        }
      } catch (error) {
        if (this.config.failFast) {
          throw error;
        }
        // Continue with other scanners
      }
    }
    
    return results;
  }

  private async executeSingleScanner(
    scanner: Scanner,
    request: ScanRequest
  ): Promise<SecurityScanResult | null> {
    this.activeScanCount++;
    this.emit('scanner:start', scanner.name);
    
    try {
      // Check if scanner is available
      const isAvailable = await scanner.isAvailable();
      if (!isAvailable) {
        this.emit('scanner:unavailable', scanner.name);
        return null;
      }

      // Execute scan
      const result = await scanner.scan(request.target, {
        ...request.options,
        metadata: request.metadata
      });
      
      this.emit('scanner:complete', scanner.name, result);
      return result;
    } catch (error) {
      this.emit('scanner:error', scanner.name, error);
      if (this.config.failFast) {
        throw error;
      }
      return null;
    } finally {
      this.activeScanCount--;
    }
  }

  private createSummary(
    request: ScanRequest,
    results: SecurityScanResult[],
    startTime: Date
  ): ScanSummary {
    const endTime = new Date();
    const summary: ScanSummary = {
      requestId: request.id,
      target: request.target,
      startTime,
      endTime,
      totalFindings: 0,
      findingsBySeverity: {
        critical: 0,
        high: 0,
        medium: 0,
        low: 0,
        info: 0
      },
      findingsByScanner: {},
      failedScanners: [],
      results
    };

    // Aggregate findings
    for (const result of results) {
      if (result.status === 'failure') {
        summary.failedScanners.push(result.scanner);
        continue;
      }

      summary.totalFindings += result.findings.length;
      summary.findingsByScanner[result.scanner] = result.findings.length;

      // Count by severity
      for (const finding of result.findings) {
        summary.findingsBySeverity[finding.severity]++;
      }
    }

    return summary;
  }

  private hasCriticalFindings(results: SecurityScanResult[]): boolean {
    return results.some(result => 
      result.findings.some(finding => finding.severity === 'critical')
    );
  }

  // Scanner management methods
  registerScanner(scanner: Scanner): void {
    this.scanners.set(scanner.name, scanner);
    this.emit('scanner:registered', scanner.name);
  }

  unregisterScanner(name: string): void {
    this.scanners.delete(name);
    this.emit('scanner:unregistered', name);
  }

  listScanners(): string[] {
    return Array.from(this.scanners.keys());
  }

  async getScannerInfo(name: string): Promise<any> {
    const scanner = this.scanners.get(name);
    if (!scanner) {
      throw new Error(`Scanner ${name} not found`);
    }

    const isAvailable = await scanner.isAvailable();
    const version = await scanner.getVersion();

    return {
      name: scanner.name,
      type: scanner.type,
      available: isAvailable,
      version
    };
  }

  // Utility methods
  async checkAllScanners(): Promise<Record<string, boolean>> {
    const status: Record<string, boolean> = {};
    
    for (const [name, scanner] of this.scanners) {
      try {
        status[name] = await scanner.isAvailable();
      } catch {
        status[name] = false;
      }
    }
    
    return status;
  }

  getActiveScanCount(): number {
    return this.activeScanCount;
  }

  // Result filtering and deduplication
  deduplicateFindings(results: SecurityScanResult[]): SecurityFinding[] {
    const uniqueFindings = new Map<string, SecurityFinding>();
    
    for (const result of results) {
      for (const finding of result.findings) {
        // Create a unique key for the finding
        const key = this.createFindingKey(finding);
        
        // Keep the highest severity version if duplicate
        const existing = uniqueFindings.get(key);
        if (!existing || this.compareSeverity(finding.severity, existing.severity) > 0) {
          uniqueFindings.set(key, finding);
        }
      }
    }
    
    return Array.from(uniqueFindings.values());
  }

  private createFindingKey(finding: SecurityFinding): string {
    const parts = [
      finding.type,
      finding.location?.file || 'unknown',
      finding.location?.line?.toString() || '0',
      finding.title.toLowerCase().replace(/\s+/g, '-')
    ];
    
    if (finding.cve) {
      parts.push(finding.cve);
    }
    
    return parts.join(':');
  }

  private compareSeverity(a: string, b: string): number {
    const severityOrder = ['info', 'low', 'medium', 'high', 'critical'];
    return severityOrder.indexOf(a) - severityOrder.indexOf(b);
  }
}

// Export singleton instance
export const scannerOrchestrator = new ScannerOrchestrator();