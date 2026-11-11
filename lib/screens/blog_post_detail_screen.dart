import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/blog_service.dart';

class BlogPostDetailScreen extends StatefulWidget {
  final String postId;

  const BlogPostDetailScreen({super.key, required this.postId});

  @override
  State<BlogPostDetailScreen> createState() => _BlogPostDetailScreenState();
}

class _BlogPostDetailScreenState extends State<BlogPostDetailScreen> {
  final BlogService _service = BlogService();
  Map<String, dynamic>? _post;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _service.getBlogPost(widget.postId);
      setState(() {
        _post = data['post'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load blog post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: const Text('Blog Post'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('Post not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_post!['featured_image'] != null)
                        Image.network(
                          _post!['featured_image'] as String,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 250,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 64),
                            );
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _post!['title'] as String,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: kBlackColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.person, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  _post!['author']['name'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.visibility, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  '${_post!['views']} views',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if (_post!['published_at'] != null) ...[
                                  const SizedBox(width: 16),
                                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateTime.parse(_post!['published_at'] as String).toString().split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_post!['excerpt'] != null && (_post!['excerpt'] as String).isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: kAccentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _post!['excerpt'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              _post!['content'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: kBlackColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

