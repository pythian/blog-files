# Product Context

This file provides a high-level overview of the project and the expected product that will be created. Initially it is based upon projectBrief.md (if provided) and all other available project-related information in the working directory. This file is intended to be updated as the project evolves, and should be used to inform all other modes of the project's goals and context.
## Project Goal

The primary goal of this project is to build a robust, containerized, and well-documented RESTful API for a blog platform.

## Key Features

*   **CRUD Operations:** Full Create, Read, Update, and Delete API endpoint functionality for blog posts.
*   **Containerized Environment:** The entire application and its dependencies are managed by Docker and Docker Compose for a consistent and reproducible development environment.
*   **API Documentation:** Interactive API documentation is automatically generated using OpenAPI (Swagger).

## Overall Architecture

The project is a RESTful API built on a modern technology stack:

*   **Backend:** Node.js (v22) with the Express.js framework.
*   **Database:** PostgreSQL (v17) for data persistence.
*   **ORM:** Sequelize for object-relational mapping between the application and the database.
*   **Containerization:** Docker and Docker Compose for creating and managing the development and testing environments.
*   **API Documentation:** Swagger UI and swagger-jsdoc for generating interactive documentation.


## API Endpoint Specifications

### Blog Posts

*   **GET /posts**
    *   **Description:** Retrieves a list of all blog posts.
    *   **Success Response:** `200 OK` with a JSON array of post objects.
    *   **Error Response:** `500 Internal Server Error` if there's a server-side issue.

*   **GET /posts/:id**
    *   **Description:** Retrieves a single blog post by its ID.
    *   **Success Response:** `200 OK` with a JSON object for the post.
    *   **Error Responses:**
        *   `404 Not Found` if the post with the specified ID doesn't exist.
        *   `500 Internal Server Error` for other server-side issues.

*   **POST /posts**
    *   **Description:** Creates a new blog post.
    *   **Request Body:** JSON object with `title` (string) and `content` (string).
    *   **Success Response:** `201 Created` with the newly created post object.
    *   **Error Responses:**
        *   `400 Bad Request` if the request body is missing required fields or is malformed.
        *   `500 Internal Server Error` for other server-side issues.

*   **PUT /posts/:id**
    *   **Description:** Updates an existing blog post.
    *   **Request Body:** JSON object with `title` (string) and/or `content` (string).
    *   **Success Response:** `200 OK` with the updated post object.
    *   **Error Responses:**
        *   `400 Bad Request` if the request body is malformed.
        *   `404 Not Found` if the post with the specified ID doesn't exist.
        *   `500 Internal Server Error` for other server-side issues.

*   **DELETE /posts/:id**
    *   **Description:** Deletes a blog post.
    *   **Success Response:** `204 No Content`.
    *   **Error Responses:**
        *   `404 Not Found` if the post with the specified ID doesn't exist.
        *   `500 Internal Server Error` for other server-side issues.


## Database Schema

### `posts` table

| Column      | Data Type     | Constraints              | Description                               |
|-------------|---------------|--------------------------|-------------------------------------------|
| `id`        | `INTEGER`     | `PRIMARY KEY`, `AUTOINCREMENT` | Unique identifier for the post.           |
| `title`     | `VARCHAR(255)`| `NOT NULL`               | The title of the blog post.               |
| `content`   | `TEXT`        | `NOT NULL`               | The main content of the blog post.        |
| `createdAt` | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`  | Timestamp of when the post was created.   |
| `updatedAt` | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`  | Timestamp of the last update to the post. |
