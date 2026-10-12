"""Seed v1 data: users, restaurants, menus. Idempotent — safe to re-run.

Usage:  python -m app.v1.seed
"""

from sqlalchemy import select

from app.database import SessionLocal, init_db
from app.v1.auth import hash_password
from app.v1.models import MenuItem, Restaurant, User

CUSTOMER_EMAIL = "customer@example.com"
ADMIN_EMAIL = "admin@example.com"

RESTAURANTS = [
    {
        "id": "rest_biryani",
        "name": "Biryani Blues",
        "description": "Dum biryanis and kebabs",
        "items": [
            ("item_chicken_biryani", "Chicken Dum Biryani", "Fragrant basmati, saffron, mirchi ka salan", 24999),
            ("item_veg_biryani", "Veg Dum Biryani", "Seasonal vegetables, fried onions", 19999),
            ("item_kebab_platter", "Kebab Platter", "Chicken tikka, seekh kebab, tangdi", 34999),
            ("item_raita", "Burhani Raita", "Garlic-mint raita", 4999),
            ("item_gulab_jamun", "Gulab Jamun (4 pc)", "Warm, syrup-soaked", 9999),
        ],
    },
    {
        "id": "rest_pizza",
        "name": "Slice Society",
        "description": "Wood-fired pizzas",
        "items": [
            ("item_margherita", "Margherita", "San Marzano tomato, fior di latte, basil", 29999),
            ("item_paneer_tikka_pizza", "Paneer Tikka Pizza", "Smoky paneer, onions, mint drizzle", 34999),
            ("item_garlic_bread", "Garlic Breadsticks", "With marinara dip", 14999),
            ("item_tiramisu", "Tiramisu", "Espresso-soaked, mascarpone", 19999),
        ],
    },
    {
        "id": "rest_dosa",
        "name": "Dosa District",
        "description": "South Indian classics",
        "items": [
            ("item_masala_dosa", "Masala Dosa", "Crisp crepe, potato palya, trio of chutneys", 12999),
            ("item_idli_sambar", "Idli Sambar (4 pc)", "Soft idlis, drumstick sambar", 8999),
            ("item_filter_coffee", "Filter Coffee", "Degree coffee, frothed milk", 5999),
            ("item_medu_vada", "Medu Vada (3 pc)", "Crisp, with coconut chutney", 7999),
        ],
    },
]


def seed():
    init_db()
    session = SessionLocal()
    try:
        # Users
        for email, name, role, password in [
            (CUSTOMER_EMAIL, "Test Customer", "customer", "customer123"),
            (ADMIN_EMAIL, "Test Admin", "admin", "admin123"),
        ]:
            exists = session.execute(select(User).where(User.email == email)).scalar_one_or_none()
            if not exists:
                session.add(User(
                    email=email, name=name, role=role,
                    password_hash=hash_password(password),
                ))
                print(f"created user {email} / {password}")
            else:
                print(f"user exists: {email}")

        # Restaurants + menus
        for r in RESTAURANTS:
            rest = session.execute(
                select(Restaurant).where(Restaurant.id == r["id"])
            ).scalar_one_or_none()
            if not rest:
                rest = Restaurant(id=r["id"], name=r["name"], description=r["description"])
                session.add(rest)
                print(f"created restaurant {r['name']}")
            for item_id, name, desc, price_minor in r["items"]:
                mi = session.execute(
                    select(MenuItem).where(MenuItem.id == item_id)
                ).scalar_one_or_none()
                if not mi:
                    session.add(MenuItem(
                        id=item_id, restaurant_id=r["id"], name=name,
                        description=desc, price_minor=price_minor, currency="INR",
                    ))
        session.commit()
        print("seed complete")
    finally:
        session.close()


if __name__ == "__main__":
    seed()
