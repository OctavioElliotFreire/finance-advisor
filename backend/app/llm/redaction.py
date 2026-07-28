from app.models.anomaly import AnomalyFlag
from app.models.transaction import Transaction

DESCRIPTION_MAX_LENGTH = 80


def redact_transaction_context(flag: AnomalyFlag, transaction: Transaction | None) -> dict:
    """Builds the only data ever sent to the LLM for one anomaly explanation.

    Explicit whitelist — never passes `raw_json`, the ORM object, or any
    Pluggy identifier/account number. `Transaction`/`Account` already dropped
    most PII columns (no CNPJ, no account numbers), so this whitelist is
    intentionally short.
    """
    context = {
        "rule": flag.rule,
        "severity": flag.severity,
        "summary": flag.summary,
    }
    if transaction is not None:
        description = transaction.description or ""
        context.update(
            {
                "description": description[:DESCRIPTION_MAX_LENGTH],
                "amount": float(transaction.amount),
                "currency_code": transaction.currency_code,
                "category": transaction.category,
                "transaction_date": transaction.transaction_date.isoformat(),
            }
        )
    return context
