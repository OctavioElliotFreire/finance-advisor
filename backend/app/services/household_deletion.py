import uuid

from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.assistant import AssistantMessage
from app.models.connection_access_grant import ConnectionAccessGrant
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.household import Household, HouseholdMember
from app.models.household_invite import HouseholdInvite
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.models.transaction import Transaction


def delete_household(db: Session, household_id: uuid.UUID) -> None:
    """Deletes a household and every row that belongs to it, in dependency
    order. `audit_events` is deliberately left untouched — its FK is
    `ON DELETE SET NULL` (see the migration that added it), so any audit
    trail for this household survives with `household_id` nulled out
    rather than being deleted along with the household. `rate_limit_hits`
    is also left alone: it's a scope-keyed counter with no FK, and an
    orphaned scope string is harmless (it will simply never match again).
    """
    member_ids = [
        row[0]
        for row in db.query(HouseholdMember.id)
        .filter(HouseholdMember.household_id == household_id)
        .all()
    ]
    account_ids = [
        row[0]
        for row in db.query(Account.id).filter(Account.household_id == household_id).all()
    ]

    if member_ids:
        db.query(ConnectionAccessGrant).filter(
            ConnectionAccessGrant.household_member_id.in_(member_ids)
        ).delete(synchronize_session=False)

    db.query(HouseholdInvite).filter(HouseholdInvite.household_id == household_id).delete(
        synchronize_session=False
    )
    db.query(AssistantMessage).filter(
        AssistantMessage.household_id == household_id
    ).delete(synchronize_session=False)
    db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household_id).delete(
        synchronize_session=False
    )
    if account_ids:
        db.query(CreditCardBill).filter(CreditCardBill.account_id.in_(account_ids)).delete(
            synchronize_session=False
        )
        db.query(BalanceSnapshot).filter(
            BalanceSnapshot.account_id.in_(account_ids)
        ).delete(synchronize_session=False)
    db.query(Investment).filter(Investment.household_id == household_id).delete(
        synchronize_session=False
    )
    db.query(Loan).filter(Loan.household_id == household_id).delete(synchronize_session=False)
    db.query(Transaction).filter(Transaction.household_id == household_id).delete(
        synchronize_session=False
    )
    db.query(Account).filter(Account.household_id == household_id).delete(
        synchronize_session=False
    )
    db.query(SyncJob).filter(SyncJob.household_id == household_id).delete(
        synchronize_session=False
    )
    db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household_id
    ).delete(synchronize_session=False)
    db.query(HouseholdMember).filter(
        HouseholdMember.household_id == household_id
    ).delete(synchronize_session=False)
    db.query(Household).filter(Household.id == household_id).delete(
        synchronize_session=False
    )
