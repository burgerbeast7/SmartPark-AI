import os
from PIL import Image, ImageDraw, ImageFont

ASSETS_DIR = r'k:\parking applicat\smartpark_ai\docs\assets'
os.makedirs(ASSETS_DIR, exist_ok=True)

font_title = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 24)
font_head = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 17)
font_body = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 14)
font_sm = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 12)

# -------------------------------------------------------------
# 1. Architecture Diagram
# -------------------------------------------------------------
w, h = 1200, 780
img1 = Image.new('RGB', (w, h), color=(255, 255, 255))
d1 = ImageDraw.Draw(img1)
d1.rectangle([10, 10, w-10, h-10], outline=(200, 210, 225), width=2)
d1.text((40, 25), 'SmartPark AI: Four-Layer Modular Architecture', fill=(26, 58, 92), font=font_title)

layers = [
    ('PRESENTATION LAYER (Material 3 Mobile UI)', 
     'Screens: Dashboard • Vehicle Entry • Vehicle Exit • Active Parking • History • Reports • Tariff Settings\n'
     'Widgets: Suggestion Chips Modal • Bill Breakdown Dialog • Payment Selector • Printable Receipt Sheet\n'
     'Characteristics: Locked to Portrait, Material 3 Design Tokens, Scrollable Forms, 48dp Touch Targets', 
     (26, 58, 92), (235, 243, 250)),
    ('STATE MANAGEMENT LAYER (Provider & ChangeNotifier)', 
     'ParkingProvider with Monotonic Revision Counter\n'
     'Unidirectional Data Flow: UI triggers Action -> Service mutates SQLite -> Provider bumps Revision -> Tabs Rebuild\n'
     'Ensures that persistent bottom-navigation tabs refresh immediately upon vehicle entry, exit, or tariff changes', 
     (46, 64, 87), (240, 244, 248)),
    ('DOMAIN SERVICE LAYER (Pure Dart Business Logic)', 
     'OcrService: Google ML Kit Latin Script Recognizer with Scoped Lifecycle and Garbage Collection\n'
     'PlateService: Alphanumeric Cleaning, Length Validation (4-12 chars), State Regex & Bharat Series (BH) Ranking\n'
     'BillingService: Deterministic Integer Tariff Engine (STARTED_HOUR / FULL_HOUR, Grace Period, Whole Rupees)\n'
     'ParkingService: Active Session Discovery, Duplicate Validation, Atomic Exit Status & Receipt Generation\n'
     'CsvService: RFC 4180 Compliant Data Serializer interfacing directly with the Android Share Sheet', 
     (14, 140, 127), (235, 248, 246)),
    ('DATA PERSISTENCE LAYER (ACID-Compliant Embedded SQLite)', 
     'Engine: SQLite via sqflite with PRAGMA foreign_keys = ON and Atomic Multi-Row Transaction Blocks\n'
     'tariff_settings: Single-row configuration (CHECK id=1) storing hourly rates, grace, rounding, and lot capacity\n'
     'parking_sessions: Records plate, category, UTC entry/exit epoch ms, duration, fee, and immutable tariff snapshot\n'
     'payments: Relational records linked to sessions with payment method (CASH/UPI) and status (UNPAID/PAID)\n'
     'Integrity: Partial Unique Index ux_active_plate guarantees zero duplicate active vehicle sessions', 
     (27, 38, 59), (240, 242, 245))
]

y = 75
for title, desc, title_col, bg_col in layers:
    d1.rounded_rectangle([40, y, w-40, y+155], radius=10, fill=bg_col, outline=title_col, width=2)
    d1.text((60, y+12), title, fill=title_col, font=font_head)
    d1.text((60, y+45), desc, fill=(35, 40, 45), font=font_body)
    y += 170

img1.save(os.path.join(ASSETS_DIR, 'diag_architecture.png'))

# -------------------------------------------------------------
# 2. Vehicle Entry Workflow (from Section 4A.3 of Project Plan)
# -------------------------------------------------------------
w, h = 1200, 760
img2 = Image.new('RGB', (w, h), color=(255, 255, 255))
d2 = ImageDraw.Draw(img2)
d2.rectangle([10, 10, w-10, h-10], outline=(200, 210, 225), width=2)
d2.text((40, 20), 'Vehicle Entry Workflow (Section 4A.3 of Project Plan)', fill=(26, 58, 92), font=font_title)

boxes_entry = [
    (50, 70, 290, 145, '1. Start Entry', 'Operator opens Vehicle Entry screen\nand taps "Capture Plate"', (26, 58, 92), (235, 243, 250)),
    (340, 70, 600, 145, '2. Camera Capture', 'System Camera opens via intent\nOperator snaps vehicle number plate', (46, 64, 87), (240, 244, 248)),
    (650, 70, 910, 145, '3. On-Device OCR', 'Google ML Kit Latin model scans image\nExtracts candidate text blocks', (14, 140, 127), (235, 248, 246)),
    (960, 70, 1150, 145, '4. Normalization', 'PlateService filters 4-12 chars\nRanks State & BH candidates', (27, 38, 59), (240, 242, 245)),
    
    (50, 240, 360, 335, '5. Pre-Fill & Review', 'Best candidate pre-fills plate field\nOther candidates shown as chips\nOperator picks Category (Car/Bike)', (26, 58, 92), (235, 243, 250)),
    (430, 240, 740, 335, '6. Human Confirmation', 'Operator verifies number plate text\nEdits manually if lighting caused misread\nTaps "Confirm Entry" button', (14, 140, 127), (235, 248, 246)),
    (810, 240, 1150, 335, '7. Active Session Check', 'System queries SQLite database:\nDoes plate already have status = ACTIVE?\n(Checked via partial unique index)', (180, 100, 20), (255, 248, 235)),
    
    (140, 430, 520, 545, 'REJECTION / ERROR PATH', 'If active session exists:\nRefuse entry: "Vehicle already parked!"\nIf length < 4 or > 12: Show format error\nNo active record is saved', (180, 30, 30), (255, 238, 238)),
    (680, 430, 1060, 545, 'SUCCESSFUL PERSISTENCE', 'Save new session: plate, category, entry_time=now\nStatus = ACTIVE, exit_time = NULL\nDatabase revision bumped -> UI Dashboard updates\nShow success toast and reset form', (20, 130, 50), (235, 252, 240)),
]

for x1, y1, x2, y2, title, desc, b_col, bg_col in boxes_entry:
    d2.rounded_rectangle([x1, y1, x2, y2], radius=8, fill=bg_col, outline=b_col, width=2)
    d2.text((x1+15, y1+10), title, fill=b_col, font=font_head)
    d2.text((x1+15, y1+38), desc, fill=(35, 40, 45), font=font_sm)

d2.line([(290, 107), (340, 107)], fill=(26, 58, 92), width=3)
d2.line([(600, 107), (650, 107)], fill=(46, 64, 87), width=3)
d2.line([(910, 107), (960, 107)], fill=(14, 140, 127), width=3)

d2.line([(1055, 145), (1055, 192), (205, 192), (205, 240)], fill=(70, 80, 95), width=3)
d2.line([(360, 287), (430, 287)], fill=(26, 58, 92), width=3)
d2.line([(740, 287), (810, 287)], fill=(14, 140, 127), width=3)

d2.line([(900, 335), (900, 380), (330, 380), (330, 430)], fill=(180, 30, 30), width=3)
d2.text((345, 390), 'Yes, Already Parked (Conflict)', fill=(180, 30, 30), font=font_sm)

d2.line([(1050, 335), (1050, 380), (870, 380), (870, 430)], fill=(20, 130, 50), width=3)
d2.text((885, 390), 'No, Valid Unique Plate', fill=(20, 130, 50), font=font_sm)

d2.text((50, 600), 'Core Invariant: Foreign keys and partial index (ux_active_plate) guarantee that duplicate active entries cannot occur.', fill=(80, 90, 100), font=font_body)
d2.text((50, 630), 'Local-First Guarantee: Entire entry workflow executes 100% offline with zero cloud latency and sub-1.5s OCR response.', fill=(80, 90, 100), font=font_body)

img2.save(os.path.join(ASSETS_DIR, 'diag_entry_workflow.png'))

# -------------------------------------------------------------
# 3. Vehicle Exit Workflow (from Section 4A.4 of Project Plan)
# -------------------------------------------------------------
w, h = 1200, 780
img3 = Image.new('RGB', (w, h), color=(255, 255, 255))
d3 = ImageDraw.Draw(img3)
d3.rectangle([10, 10, w-10, h-10], outline=(200, 210, 225), width=2)
d3.text((40, 20), 'Vehicle Exit & Concurrency Guard Workflow (Section 4A.4 of Project Plan)', fill=(26, 58, 92), font=font_title)

boxes_exit = [
    (50, 70, 300, 145, '1. Locate Vehicle', 'Operator scans plate via camera OCR,\ntypes plate, or selects from Active List', (26, 58, 92), (235, 243, 250)),
    (360, 70, 660, 145, '2. Active Session Lookup', 'Query: SELECT * FROM parking_sessions\nWHERE plate_number = ? AND status=\'ACTIVE\'', (46, 64, 87), (240, 244, 248)),
    (720, 70, 1150, 145, '3. Timestamp Locking & Validation', 'Lock exit_time = now (UTC milliseconds)\nValidate: exit_time >= entry_time\nDuration D = (exit_time - entry_time) ~/ 60000', (14, 140, 127), (235, 248, 246)),
    
    (50, 230, 420, 335, '4. Deterministic Billing Engine', 'Evaluate Grace Period: if D <= grace -> ₹0\nFirst Hour: FirstHourRate (covers initial 60m)\nAdditional Hours: (rem + 59) ~/ 60 * AddRate\nTotal Fee = FirstRate + AdditionalCharges', (26, 58, 92), (235, 243, 250)),
    (480, 230, 800, 335, '5. Payment Recording', 'Display Bill Breakdown & Total\nSelect Payment Method: CASH / UPI\nSelect Status: PAID (default) or UNPAID\nOperator taps "Confirm Exit"', (14, 140, 127), (235, 248, 246)),
    (860, 230, 1150, 335, '6. Concurrency Protection', 'Button disabled immediately on tap\nAtomic Conditional UPDATE:\nUPDATE parking_sessions SET status=\'COMPLETED\'\nWHERE id = ? AND status = \'ACTIVE\'', (180, 100, 20), (255, 248, 235)),
    
    (100, 430, 480, 545, 'REJECTION / CONCURRENCY BLOCKS', 'If no active session found: Show error toast\nIf exit_time < entry_time: Reject timestamp\nIf rows_affected == 0: Refuse double processing\nPrevent duplicate billing on repeated clicks', (180, 30, 30), (255, 238, 238)),
    (670, 430, 1100, 545, 'TRANSACTION COMPLETION & RECEIPT', 'Save COMPLETED session with final fee & tariff snapshot\nInsert payment row (session_id, amount, method, status)\nBump provider revision counter -> Live screens refresh\nDisplay digital receipt with sharing & printing options', (20, 130, 50), (235, 252, 240)),
]

for x1, y1, x2, y2, title, desc, b_col, bg_col in boxes_exit:
    d3.rounded_rectangle([x1, y1, x2, y2], radius=8, fill=bg_col, outline=b_col, width=2)
    d3.text((x1+15, y1+10), title, fill=b_col, font=font_head)
    d3.text((x1+15, y1+38), desc, fill=(35, 40, 45), font=font_sm)

d3.line([(300, 107), (360, 107)], fill=(26, 58, 92), width=3)
d3.line([(660, 107), (720, 107)], fill=(46, 64, 87), width=3)
d3.line([(935, 145), (935, 190), (235, 190), (235, 230)], fill=(70, 80, 95), width=3)
d3.line([(420, 282), (480, 282)], fill=(26, 58, 92), width=3)
d3.line([(800, 282), (860, 282)], fill=(14, 140, 127), width=3)

d3.line([(950, 335), (950, 380), (290, 380), (290, 430)], fill=(180, 30, 30), width=3)
d3.text((310, 390), '0 Rows Affected (Double Exit Collision)', fill=(180, 30, 30), font=font_sm)

d3.line([(1060, 335), (1060, 380), (885, 380), (885, 430)], fill=(20, 130, 50), width=3)
d3.text((900, 390), 'Exactly 1 Row Updated', fill=(20, 130, 50), font=font_sm)

d3.text((50, 610), 'Audit Guarantee: Tariff snapshot is saved as immutable JSON in the completed session record, preventing retro-active drift.', fill=(80, 90, 100), font=font_body)
d3.text((50, 640), 'Financial Determinism: Duration and fee are computed exclusively using integer arithmetic, preventing IEEE-754 precision errors.', fill=(80, 90, 100), font=font_body)

img3.save(os.path.join(ASSETS_DIR, 'diag_exit_workflow.png'))

# -------------------------------------------------------------
# 4. State Machine / Lifecycle (from Section 4A.2 of Project Plan)
# -------------------------------------------------------------
w, h = 1200, 520
img4 = Image.new('RGB', (w, h), color=(255, 255, 255))
d4 = ImageDraw.Draw(img4)
d4.rectangle([10, 10, w-10, h-10], outline=(200, 210, 225), width=2)
d4.text((40, 20), 'Session & Payment State Machine Lifecycle (Section 4A.2 of Project Plan)', fill=(26, 58, 92), font=font_title)

d4.rounded_rectangle([60, 100, 340, 220], radius=10, fill=(235, 248, 246), outline=(14, 140, 127), width=3)
d4.text((80, 115), 'SESSION: ACTIVE', fill=(14, 140, 127), font=font_head)
d4.text((80, 145), '• Vehicle is currently parked in lot\n• exit_time is NULL, amount is NULL\n• Protected by ux_active_plate index\n• Visible in Active Sessions register', fill=(35, 40, 45), font=font_sm)

d4.rounded_rectangle([480, 100, 760, 220], radius=10, fill=(235, 243, 250), outline=(26, 58, 92), width=3)
d4.text((500, 115), 'SESSION: COMPLETED', fill=(26, 58, 92), font=font_head)
d4.text((500, 145), '• Vehicle has exited the facility\n• exit_time and duration are fixed\n• Final amount & tariff snapshot stored\n• Exactly 1 payment row linked', fill=(35, 40, 45), font=font_sm)

d4.rounded_rectangle([860, 70, 1140, 180], radius=10, fill=(255, 248, 235), outline=(180, 100, 20), width=3)
d4.text((880, 85), 'PAYMENT: UNPAID', fill=(180, 100, 20), font=font_head)
d4.text((880, 115), '• Cash/UPI not yet collected\n• Session completed on credit\n• Can be marked paid later in Receipt', fill=(35, 40, 45), font=font_sm)

d4.rounded_rectangle([860, 220, 1140, 330], radius=10, fill=(235, 252, 240), outline=(20, 130, 50), width=3)
d4.text((880, 235), 'PAYMENT: PAID', fill=(20, 130, 50), font=font_head)
d4.text((880, 265), '• Payment received (Cash or UPI)\n• paid_at timestamp recorded\n• Included in Today\'s Collection total', fill=(35, 40, 45), font=font_sm)

d4.line([(340, 160), (480, 160)], fill=(26, 58, 92), width=4)
d4.text((355, 135), 'Exit Confirmed', fill=(26, 58, 92), font=font_sm)

d4.line([(760, 140), (860, 125)], fill=(180, 100, 20), width=3)
d4.text((765, 105), 'Exit without cash', fill=(180, 100, 20), font=font_sm)

d4.line([(760, 180), (860, 250)], fill=(20, 130, 50), width=3)
d4.text((770, 210), 'Paid at exit', fill=(20, 130, 50), font=font_sm)

d4.line([(1000, 180), (1000, 220)], fill=(20, 130, 50), width=3)
d4.text((1015, 190), 'Mark as Paid', fill=(20, 130, 50), font=font_sm)

d4.text((60, 410), 'Architectural Decoupling: Parking session state (ACTIVE / COMPLETED) is strictly decoupled from Payment state (UNPAID / PAID).', fill=(50, 60, 70), font=font_body)
d4.text((60, 440), 'This allows vehicles to exit during peak rush hours while retaining unalterable accounts receivable records for later settlement.', fill=(50, 60, 70), font=font_body)

img4.save(os.path.join(ASSETS_DIR, 'diag_state_machine.png'))

print('All 4 workflow diagrams generated successfully!')
