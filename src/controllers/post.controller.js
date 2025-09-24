const { Post } = require('../models');

/**
 * @description Get all posts
 * @route GET /posts
 */
const getAllPosts = async (req, res) => {
  try {
    const posts = await Post.findAll();
    res.status(200).json(posts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

/**
 * @description Get a single post by ID
 * @route GET /posts/:id
 */
const getPostById = async (req, res) => {
  try {
    const { id } = req.params;
    const post = await Post.findByPk(id);
    if (post) {
      res.status(200).json(post);
    } else {
      res.status(404).json({ error: 'Post not found' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

/**
 * @description Create a new post
 * @route POST /posts
 */
const createPost = async (req, res) => {
  try {
    const { title, content } = req.body;
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content are required' });
    }
    const post = await Post.create({ title, content });
    res.status(201).json(post);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

/**
 * @description Update a post
 * @route PUT /posts/:id
 */
const updatePost = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content } = req.body;
    const post = await Post.findByPk(id);
    if (post) {
      await post.update({ title, content });
      res.status(200).json(post);
    } else {
      res.status(404).json({ error: 'Post not found' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

/**
 * @description Delete a post
 * @route DELETE /posts/:id
 */
const deletePost = async (req, res) => {
  try {
    const { id } = req.params;
    const post = await Post.findByPk(id);
    if (post) {
      await post.destroy();
      res.status(204).send();
    } else {
      res.status(404).json({ error: 'Post not found' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getAllPosts,
  getPostById,
  createPost,
  updatePost,
  deletePost,
};