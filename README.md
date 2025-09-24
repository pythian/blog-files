# Blog API

This project is a simple, containerized RESTful API for a blog platform, built with Node.js, Express, and PostgreSQL.

## Features

*   **CRUD Operations:** Full Create, Read, Update, and Delete functionality for blog posts.
*   **Containerized:** Uses Docker and Docker Compose for a consistent and reproducible environment.
*   **API Documentation:** Interactive API documentation is automatically generated using Swagger/OpenAPI.

## Prerequisites

*   [Docker](https://www.docker.com/get-started)
*   [Docker Compose](https://docs.docker.com/compose/install/)

## Getting Started

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2.  **Create an environment file:**
    Create a `.env` file in the root of the project and add the following environment variables. You can change the values if you wish.
    ```env
    # Database credentials
    DB_USER=myuser
    DB_PASSWORD=mypassword
    DB_NAME=blogdb
    DB_HOST=db
    ```

3.  **Build and run the application:**
    Use Docker Compose to build the images and start the services.
    ```bash
    docker-compose up --build
    ```
    The application will be running and accessible at `http://localhost:3000`.

## API Documentation

Once the application is running, you can access the interactive API documentation in your browser at the following URL:

[http://localhost:3000/api-docs](http://localhost:3000/api-docs)