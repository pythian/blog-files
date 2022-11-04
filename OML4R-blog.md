
# OML4R Blog

reference code: /home/jkstill/pythian/martin-brower

Not just OML4R

## Part 1 - Install Software and Prepare OS

### Java and R

- OML4R
  - OS preparation
    - java - correct version
      - not needed for OML4R, but needed later
      - R - version 3.6 required
    - prevent yum updates from updating Java or R
  - database preparation
    - oml4r/db-prep/README.md
  - Install OML4R
    - oml4r/install-oml4r.md

### SQL Developer Web
 
- SQL Developer Web
  - oml4r/SQL-Developer-Web.md
 
### Prototype App

Initial setup

- Prototype App
  - this is not yet finished
    - oml4r/proto-app/Proto-App.md
    - proto-app/CLI-Data-Access.md
  - build on this app 
    - start with SQL
    - then REST + SQL
    - Then R
      - username/password
      - then OAUTH
  - need to create R functions 
  - R cheatsheet
    - oml4r/db-prep/R-cheat-sheet.md

## Part 2 - ORDS and OAUTH

### Configure and test ORDS

- ORDS
  - oml4r/ords-install.md
  - Java - correct version
  - Test REST with Proto app
    - username/password

### Configure and test OAUTH

- OAUTH
  - I started documenting the first doc, but did not complete it
  - It may be that both docs contain all that is needed to configure oauth - needs testing
    - oml4r/ords-services/ORDS-OAUTH-Configure.md
    - oml4r/proto-app/Proto-App.md
  - This doc shows a usage of oauth
    - oml4r/proto-app/CLI-Data-Access.md
  - Test REST with Proto app
    - OAUTH authentication

## Part 3 - R via ORDS

- Prototype App
  - R functions via REST
  - authentication via OAUTH
  - show two methods of using database
    - Oracle default using OML4R R calls
	 - R calls 
	   - possible by logging into db in R
		- Why? Lengthy process to convert large R (90k) to Oracle R

