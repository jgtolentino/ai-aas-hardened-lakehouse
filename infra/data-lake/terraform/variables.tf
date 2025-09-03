variable "region" { type = string }
variable "bucket_name" { type = string }
variable "enable_object_lock" { type = bool; default = false }
variable "kms_key_arn" { type = string; default = "" } # if empty, use AES256

# Lifecycle (days)
variable "bronze_infrequent_days" { type = number; default = 7 }
variable "bronze_glacier_days"    { type = number; default = 30 }
variable "bronze_expire_days"     { type = number; default = 365 }

variable "silver_infrequent_days" { type = number; default = 30 }
variable "silver_glacier_days"    { type = number; default = 120 }
variable "silver_expire_days"     { type = number; default = 1095 }

variable "gold_infrequent_days"   { type = number; default = 60 }
variable "gold_glacier_days"      { type = number; default = 180 }
variable "gold_expire_days"       { type = number; default = 1825 }

variable "platinum_infrequent_days" { type = number; default = 90 }
variable "platinum_glacier_days"    { type = number; default = 365 }
variable "platinum_expire_days"     { type = number; default = 0 } # 0 = never