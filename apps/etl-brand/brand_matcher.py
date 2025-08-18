import re
import yaml
from typing import Dict, List, Optional
import os
from pathlib import Path

class BrandMatcher:
    def __init__(self, dictionary_path: Optional[str] = None):
        """Initialize brand matcher with dictionary"""
        self.dictionary_path = dictionary_path or self._find_dictionary()
        self.brands = self._load_dictionary()
        self.model_version = "1.0.0"
        self.dictionary_version = self._get_dictionary_version()
        
    def _find_dictionary(self) -> str:
        """Find the brand dictionary file"""
        # Look in multiple possible locations
        paths = [
            "/app/packages/shared/dictionaries/brands.yaml",
            "../../packages/brand-detection/dictionaries/brands.yaml",
            "packages/shared/dictionaries/brands.yaml",
            os.path.join(os.path.dirname(__file__), "brands.yaml")
        ]
        
        for path in paths:
            if os.path.exists(path):
                return path
                
        # Default fallback
        return "brands.yaml"
        
    def _load_dictionary(self) -> Dict:
        """Load brand dictionary from YAML"""
        try:
            with open(self.dictionary_path, 'r') as f:
                data = yaml.safe_load(f)
                return data.get('brands', {})
        except FileNotFoundError:
            # Return default brands if file not found
            return {
                'coke': {'regex': r'\b(coca[\s-]?cola|coke)\b', 'weight': 1.0},
                'pepsi': {'regex': r'\bpepsi\b', 'weight': 1.0},
                'sprite': {'regex': r'\bsprite\b', 'weight': 1.0},
                'red_bull': {'regex': r'\b(red[\s-]?bull|redbull)\b', 'weight': 1.0},
                'monster': {'regex': r'\bmonster\b', 'weight': 0.8},
                'gatorade': {'regex': r'\bgatorade\b', 'weight': 1.0},
                'powerade': {'regex': r'\bpowerade\b', 'weight': 1.0},
                'mountain_dew': {'regex': r'\b(mountain[\s-]?dew|mtn[\s-]?dew)\b', 'weight': 1.0},
                'generic': {'regex': r'.*', 'weight': 0.1}
            }
            
    def _get_dictionary_version(self) -> str:
        """Get dictionary version from file metadata or hash"""
        try:
            import hashlib
            with open(self.dictionary_path, 'rb') as f:
                return hashlib.md5(f.read()).hexdigest()[:8]
        except:
            return "default"
            
    def predict(self, text: str) -> Dict:
        """Predict brand from text"""
        text_lower = text.lower()
        best_match = None
        best_confidence = 0.0
        
        for brand_name, brand_config in self.brands.items():
            pattern = brand_config.get('regex', '')
            weight = brand_config.get('weight', 1.0)
            
            if re.search(pattern, text_lower, re.IGNORECASE):
                # Calculate confidence based on weight and match quality
                match = re.search(pattern, text_lower, re.IGNORECASE)
                match_ratio = len(match.group()) / len(text_lower)
                confidence = weight * (0.5 + 0.5 * match_ratio)
                
                if confidence > best_confidence:
                    best_confidence = confidence
                    best_match = brand_name
                    
        # Default to generic if no match
        if not best_match:
            best_match = 'generic'
            best_confidence = 0.1
            
        return {
            'brand': best_match,
            'confidence': min(best_confidence, 1.0),
            'model_version': self.model_version,
            'dictionary_version': self.dictionary_version
        }