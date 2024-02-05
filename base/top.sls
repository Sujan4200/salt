base:
  "*":
    - common.packages
services:
  "services:postgres":    
     - match: grain
     - postgres
   "services:nginx":
     - match: grain
     - nginx
