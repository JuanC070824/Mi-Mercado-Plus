from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal('0.01')

def soles(value):
    return Decimal(str(value)).quantize(CENT, rounding=ROUND_HALF_UP)

def cents(value):
    return int(soles(value) * 100)

def line_total(quantity, price):
    return soles(Decimal(str(quantity)) * Decimal(str(price)))
