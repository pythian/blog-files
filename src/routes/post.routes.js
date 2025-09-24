const express = require('express');
const router = express.Router();
const postController = require('../controllers/post.controller');

/**
 * @swagger
 * components:
 *   schemas:
 *     Post:
 *       type: object
 *       required:
 *         - title
 *         - content
 *       properties:
 *         id:
 *           type: integer
 *           description: The auto-generated id of the post
 *         title:
 *           type: string
 *           description: The title of your post
 *         content:
 *           type: string
 *           description: The post content
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: The date the post was created
 *         updatedAt:
 *           type: string
 *           format: date-time
 *           description: The date the post was last updated
 *       example:
 *         id: 1
 *         title: My First Post
 *         content: This is the content of my first post.
 *         createdAt: 2023-10-27T12:00:00.000Z
 *         updatedAt: 2023-10-27T12:00:00.000Z
 */

/**
 * @swagger
 * tags:
 *   name: Posts
 *   description: The posts managing API
 */

/**
 * @swagger
 * /posts:
 *   get:
 *     summary: Returns the list of all the posts
 *     tags: [Posts]
 *     responses:
 *       200:
 *         description: The list of the posts
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Post'
 */
router.get('/', postController.getAllPosts);

/**
 * @swagger
 * /posts/{id}:
 *   get:
 *     summary: Get the post by id
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: integer
 *         required: true
 *         description: The post id
 *     responses:
 *       200:
 *         description: The post description by id
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Post'
 *       404:
 *         description: The post was not found
 */
router.get('/:id', postController.getPostById);

/**
 * @swagger
 * /posts:
 *   post:
 *     summary: Create a new post
 *     tags: [Posts]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Post'
 *     responses:
 *       201:
 *         description: The post was successfully created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Post'
 *       400:
 *         description: Bad request
 *       500:
 *         description: Some server error
 */
router.post('/', postController.createPost);

/**
 * @swagger
 * /posts/{id}:
 *   put:
 *     summary: Update the post by the id
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: integer
 *         required: true
 *         description: The post id
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Post'
 *     responses:
 *       200:
 *         description: The post was updated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Post'
 *       404:
 *         description: The post was not found
 *       500:
 *         description: Some server error
 */
router.put('/:id', postController.updatePost);

/**
 * @swagger
 * /posts/{id}:
 *   delete:
 *     summary: Remove the post by id
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: integer
 *         required: true
 *         description: The post id
 *     responses:
 *       204:
 *         description: The post was deleted
 *       404:
 *         description: The post was not found
 */
router.delete('/:id', postController.deletePost);

module.exports = router;