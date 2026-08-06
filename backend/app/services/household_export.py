import uuid

from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection
from app.models.transaction import Transaction


def build_household_export(
    db: Session, household_id: uuid.UUID, connection_ids: set[uuid.UUID] | None
) -> dict:
    """Full data-portability export for one household, scoped the same way
    as every other read in this app: `connection_ids=None` (owner, or a
    member granted every connection) returns everything, otherwise only
    data attributable to a granted bank connection. Unlike
    `household_context.py`'s LLM context, this is uncapped and includes
    `raw_json` — it's the member's own data going back to them, not a
    third-party LLM prompt, so there's no size cap or redaction to apply.
    """
    household = db.query(Household).filter(Household.id == household_id).one()

    member_rows = (
        db.query(HouseholdMember, AppUser.email)
        .join(AppUser, AppUser.id == HouseholdMember.app_user_id)
        .filter(HouseholdMember.household_id == household_id)
        .all()
    )
    members = [
        {"email": email, "role": member.role, "created_at": member.created_at}
        for member, email in member_rows
    ]

    connections_query = db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household_id
    )
    if connection_ids is not None:
        connections_query = connections_query.filter(PluggyConnection.id.in_(connection_ids))
    connections = [
        {
            "id": c.id,
            "pluggy_item_id": c.pluggy_item_id,
            "status": c.status,
            "created_at": c.created_at,
        }
        for c in connections_query.all()
    ]

    accounts_query = db.query(Account).filter(Account.household_id == household_id)
    if connection_ids is not None:
        accounts_query = accounts_query.filter(Account.pluggy_connection_id.in_(connection_ids))
    accounts = accounts_query.all()
    account_ids = [a.id for a in accounts]

    transactions_query = db.query(Transaction).filter(Transaction.household_id == household_id)
    if connection_ids is not None:
        transactions_query = transactions_query.filter(Transaction.account_id.in_(account_ids))

    balances_query = db.query(BalanceSnapshot).filter(
        BalanceSnapshot.household_id == household_id
    )
    if connection_ids is not None:
        balances_query = balances_query.filter(BalanceSnapshot.account_id.in_(account_ids))

    bills_query = db.query(CreditCardBill).filter(CreditCardBill.household_id == household_id)
    if connection_ids is not None:
        bills_query = bills_query.filter(CreditCardBill.account_id.in_(account_ids))

    investments_query = db.query(Investment).filter(Investment.household_id == household_id)
    if connection_ids is not None:
        investments_query = investments_query.filter(
            Investment.pluggy_connection_id.in_(connection_ids)
        )

    loans_query = db.query(Loan).filter(Loan.household_id == household_id)
    if connection_ids is not None:
        loans_query = loans_query.filter(Loan.pluggy_connection_id.in_(connection_ids))

    anomalies_query = db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household_id)
    if connection_ids is not None:
        # Category-deviation flags (transaction_id is NULL) can't be
        # attributed to a connection — excluded for restricted members,
        # same rule as everywhere else this household's anomalies show up.
        anomalies_query = (
            anomalies_query.join(Transaction, AnomalyFlag.transaction_id == Transaction.id)
            .filter(Transaction.account_id.in_(account_ids))
        )

    return {
        "household": {"id": household.id, "name": household.name},
        "members": members,
        "connections": connections,
        "accounts": [
            {
                "id": a.id,
                "pluggy_connection_id": a.pluggy_connection_id,
                "name": a.name,
                "type": a.type,
                "subtype": a.subtype,
                "number": a.number,
                "balance": a.balance,
                "currency_code": a.currency_code,
                "credit_limit": a.credit_limit,
                "available_credit_limit": a.available_credit_limit,
                "raw_json": a.raw_json,
            }
            for a in accounts
        ],
        "transactions": [
            {
                "id": t.id,
                "account_id": t.account_id,
                "description": t.description,
                "amount": t.amount,
                "currency_code": t.currency_code,
                "transaction_date": t.transaction_date,
                "category": t.category,
                "raw_json": t.raw_json,
            }
            for t in transactions_query.all()
        ],
        "balance_history": [
            {
                "account_id": b.account_id,
                "balance": b.balance,
                "currency_code": b.currency_code,
                "snapshot_date": b.snapshot_date,
            }
            for b in balances_query.all()
        ],
        "credit_card_bills": [
            {
                "account_id": b.account_id,
                "due_date": b.due_date,
                "closing_date": b.closing_date,
                "total_amount": b.total_amount,
                "minimum_payment": b.minimum_payment,
                "currency_code": b.currency_code,
                "raw_json": b.raw_json,
            }
            for b in bills_query.all()
        ],
        "investments": [
            {
                "id": i.id,
                "pluggy_connection_id": i.pluggy_connection_id,
                "name": i.name,
                "type": i.type,
                "subtype": i.subtype,
                "balance": i.balance,
                "value": i.value,
                "quantity": i.quantity,
                "currency_code": i.currency_code,
                "investment_date": i.investment_date,
                "raw_json": i.raw_json,
            }
            for i in investments_query.all()
        ],
        "loans": [
            {
                "id": loan.id,
                "pluggy_connection_id": loan.pluggy_connection_id,
                "type": loan.type,
                "status": loan.status,
                "contract_amount": loan.contract_amount,
                "outstanding_balance": loan.outstanding_balance,
                "installment_amount": loan.installment_amount,
                "installments_total": loan.installments_total,
                "installments_paid": loan.installments_paid,
                "due_date": loan.due_date,
                "interest_rate": loan.interest_rate,
                "currency_code": loan.currency_code,
                "raw_json": loan.raw_json,
            }
            for loan in loans_query.all()
        ],
        "anomalies": [
            {
                "id": flag.id,
                "transaction_id": flag.transaction_id,
                "rule": flag.rule,
                "severity": flag.severity,
                "summary": flag.summary,
                "status": flag.status,
                "explanation": flag.explanation,
                "created_at": flag.created_at,
            }
            for flag in anomalies_query.all()
        ],
    }
