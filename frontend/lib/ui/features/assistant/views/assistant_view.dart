import 'package:flutter/material.dart';

import '../../../../data/models/assistant_message.dart';
import '../../../../data/repositories/assistant_repository.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/assistant_view_model.dart';

const _disclaimer =
    'Informational only — not financial advice, and the assistant can make mistakes.';
const _questionMaxLength = 500;

class AssistantView extends StatefulWidget {
  const AssistantView({
    super.key,
    required this.assistantRepository,
    required this.householdId,
    required this.householdName,
  });

  final AssistantRepository assistantRepository;
  final String householdId;
  final String householdName;

  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  late final _viewModel = AssistantViewModel(
    assistantRepository: widget.assistantRepository,
    householdId: widget.householdId,
  )..load();
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _viewModel.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _viewModel.isAsking) return;
    await _viewModel.ask(question);
    _questionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.householdName} · Assistant')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              ErrorBanner(message: _viewModel.errorMessage),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _disclaimer,
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
              Expanded(
                child: _viewModel.isLoading && _viewModel.messages.isEmpty
                    ? const LoadingState()
                    : _viewModel.messages.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Ask a question about your household finances',
                        body:
                            'For example: "How much did I spend on groceries this month?"',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _viewModel.messages.length,
                        itemBuilder: (context, index) {
                          return _MessageCard(
                            message: _viewModel.messages[index],
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        maxLength: _questionMaxLength,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          labelText: 'Ask about your finances',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    LoadingButton(
                      label: 'Ask',
                      isLoading: _viewModel.isAsking,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.question,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message.answer),
            const SizedBox(height: 8),
            Text(
              '${message.askedByEmail} · ${formatShortDate(message.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
