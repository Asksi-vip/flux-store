<?php
/**
 * لوحة إدارة المتجر — إضافة/تعديل/حذف الألعاب من المتصفح.
 * الرابط: http://camillecyrm.serv00.net/flux/api/admin.php
 * كلمة المرور الافتراضية في config.php — غيّرها فورًا بعد الرفع.
 */

session_start();
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/db.php';

header('Content-Type: text/html; charset=utf-8');

$msg     = '';
$error   = '';
$logged  = !empty($_SESSION['flux_admin_ok']);

// خروج
if (isset($_GET['logout'])) {
    $_SESSION['flux_admin_ok'] = false;
    session_destroy();
    header('Location: admin.php');
    exit;
}

// تسجيل الدخول
if (!$logged && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['password'])) {
    if ((string) $_POST['password'] === FLUX_ADMIN_PASSWORD) {
        $_SESSION['flux_admin_ok'] = true;
        $logged = true;
        header('Location: admin.php');
        exit;
    }
    $error = 'كلمة المرور غير صحيحة';
}

$pdo = null;
if ($logged) {
    try {
        $pdo = flux_db();
    } catch (Throwable $e) {
        $error = 'تعذر فتح قاعدة البيانات: تحقق من تفعيل pdo_sqlite وصلاحية الكتابة على مجلد data/';
    }
}

// ---------- العمليات: حفظ / حذف ----------
if ($logged && $pdo !== null && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = (string) $_POST['action'];

    if ($action === 'save') {
        $fields = flux_collect_game_input($_POST);
        $id     = (int) (isset($_POST['id']) ? $_POST['id'] : 0);
        if ($fields === null) {
            $error = 'اسم اللعبة مطلوب';
        } else {
            if ($id > 0) {
                $stmt = $pdo->prepare(
                    'UPDATE games SET name = :name, description = :description, price = :price,
                     discount_price = :discount_price, category = :category, rating = :rating,
                     image_url = :image_url, banner_url = :banner_url,
                     release_date = :release_date, is_featured = :is_featured WHERE id = :id'
                );
                $params = flux_prefix_params($fields);
                $params[':id'] = $id;
                $stmt->execute($params);
                $msg = 'تم تحديث اللعبة بنجاح';
            } else {
                try {
                    $stmt = $pdo->prepare(
                        'INSERT INTO games (name, description, price, discount_price, category, rating,
                         image_url, banner_url, release_date, is_featured)
                         VALUES (:name, :description, :price, :discount_price, :category, :rating,
                         :image_url, :banner_url, :release_date, :is_featured)'
                    );
                    $stmt->execute(flux_prefix_params($fields));
                    $msg = 'تمت إضافة اللعبة بنجاح';
                } catch (Throwable $e) {
                    $error = 'تعذرت الإضافة — تأكد أن اسم اللعبة غير مكرر';
                }
            }
            header('Location: admin.php?msg=' . urlencode($msg));
            exit;
        }
    }

    if ($action === 'delete') {
        $id = (int) (isset($_POST['id']) ? $_POST['id'] : 0);
        if ($id > 0) {
            $stmt = $pdo->prepare('DELETE FROM games WHERE id = :id');
            $stmt->execute(array(':id' => $id));
        }
        header('Location: admin.php?msg=' . urlencode('تم حذف اللعبة'));
        exit;
    }
}

// رسالة نجاح بعد إعادة التوجيه
if (isset($_GET['msg'])) {
    $msg = (string) $_GET['msg'];
}

// لعبة قيد التعديل
$editGame = null;
$editId   = 0;
if ($logged && $pdo !== null && isset($_GET['edit'])) {
    $editId = (int) $_GET['edit'];
    if ($editId > 0) {
        $stmt = $pdo->prepare('SELECT * FROM games WHERE id = :id');
        $stmt->execute(array(':id' => $editId));
        $editGame = $stmt->fetch() ?: null;
    }
}

$games = array();
if ($logged && $pdo !== null) {
    $games = $pdo->query('SELECT * FROM games ORDER BY id DESC')->fetchAll();
}
$categories = flux_categories();

/** هروب آمن لأي قيمة تُطبع في HTML. */
function e($v)
{
    return htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>لوحة إدارة متجر FLUX</title>
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #101014; color: #fff; font-family: "Segoe UI", Tahoma, sans-serif; padding: 24px 16px; }
    .wrap { max-width: 980px; margin: 0 auto; }
    h1 { font-size: 22px; margin-bottom: 4px; }
    .sub { color: #b8b8c1; font-size: 13px; margin-bottom: 20px; }
    .brand { display: inline-block; background: #202024; border: 1px solid #2a2a2a; padding: 6px 14px; border-radius: 4px; font-weight: 900; letter-spacing: 3px; margin-bottom: 14px; }
    .card { background: #18181c; border: 1px solid #2a2a2a; border-radius: 6px; padding: 20px; margin-bottom: 20px; }
    .alert-ok { background: rgba(47,191,113,.12); border: 1px solid #2fbf71; color: #2fbf71; padding: 10px 14px; border-radius: 4px; margin-bottom: 14px; font-size: 14px; }
    .alert-err { background: rgba(224,69,90,.12); border: 1px solid #e0455a; color: #ff8a99; padding: 10px 14px; border-radius: 4px; margin-bottom: 14px; font-size: 14px; }
    label { display: block; font-size: 12px; color: #b8b8c1; margin: 12px 0 6px; }
    input[type=text], input[type=password], input[type=number], input[type=date], input[type=url], select, textarea {
        width: 100%; background: #202024; border: 1px solid #2a2a2a; color: #fff;
        padding: 10px 12px; border-radius: 4px; font-size: 14px; font-family: inherit;
    }
    input:focus, select:focus, textarea:focus { outline: none; border-color: #0074e4; }
    textarea { min-height: 90px; resize: vertical; }
    .row { display: flex; gap: 12px; flex-wrap: wrap; }
    .row > div { flex: 1 1 150px; }
    .btn { display: inline-block; background: #0074e4; color: #fff; border: none; padding: 11px 26px;
           border-radius: 4px; font-size: 14px; font-weight: 700; cursor: pointer; margin-top: 16px; font-family: inherit; }
    .btn:hover { background: #1a85ee; }
    .btn-ghost { background: transparent; border: 1px solid #2a2a2a; color: #fff; }
    .btn-danger { background: transparent; border: 1px solid #e0455a; color: #ff8a99; padding: 6px 12px; margin: 0; font-size: 12px; }
    .btn-edit { background: transparent; border: 1px solid #2a2a2a; color: #26bbff; padding: 6px 12px; margin: 0; font-size: 12px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { text-align: right; color: #b8b8c1; font-weight: 600; padding: 8px; border-bottom: 1px solid #2a2a2a; }
    td { padding: 8px; border-bottom: 1px solid #1f1f24; vertical-align: middle; }
    td img { width: 44px; height: 60px; object-fit: cover; border-radius: 3px; display: block; }
    .tag { background: #0074e4; padding: 2px 8px; border-radius: 3px; font-size: 11px; font-weight: 700; }
    .tag-free { background: rgba(38,187,255,.15); border: 1px solid #26bbff; color: #26bbff; }
    .actions { display: flex; gap: 6px; }
    .check { display: flex; align-items: center; gap: 8px; margin-top: 14px; font-size: 14px; color: #fff; }
    .check input { width: auto; }
    @media (max-width: 640px) { td:nth-child(3), th:nth-child(3) { display: none; } }
</style>
</head>
<body>
<div class="wrap">
    <div class="brand">FLUX</div>
    <h1>لوحة إدارة المتجر</h1>
    <p class="sub">إضافة وتعديل وحذف ألعاب الـ API — التغييرات تظهر في التطبيق فورًا</p>

    <?php if ($msg !== '') { ?><div class="alert-ok"><?php echo e($msg); ?></div><?php } ?>
    <?php if ($error !== '') { ?><div class="alert-err"><?php echo e($error); ?></div><?php } ?>

    <?php if (!$logged) { ?>
        <!-- شاشة تسجيل الدخول -->
        <div class="card" style="max-width:420px;">
            <form method="post" action="admin.php">
                <label>كلمة مرور الإدارة</label>
                <input type="password" name="password" required autofocus>
                <button class="btn" type="submit">دخول</button>
            </form>
        </div>
    <?php } else { ?>

        <?php if ($pdo === null) { ?>
            <div class="card">لا يمكن الاتصال بقاعدة البيانات.</div>
        <?php } else { ?>

            <!-- نموذج الإضافة/التعديل -->
            <div class="card">
                <h2 style="font-size:16px; margin-bottom:4px;">
                    <?php echo $editGame ? 'تعديل: ' . e($editGame['name']) : 'إضافة لعبة جديدة'; ?>
                </h2>
                <form method="post" action="admin.php">
                    <input type="hidden" name="action" value="save">
                    <input type="hidden" name="id" value="<?php echo $editGame ? (int) $editGame['id'] : 0; ?>">

                    <label>اسم اللعبة *</label>
                    <input type="text" name="name" required value="<?php echo $editGame ? e($editGame['name']) : ''; ?>">

                    <label>الوصف</label>
                    <textarea name="description"><?php echo $editGame ? e($editGame['description']) : ''; ?></textarea>

                    <div class="row">
                        <div>
                            <label>السعر ($)</label>
                            <input type="number" step="0.01" min="0" name="price" value="<?php echo $editGame ? e($editGame['price']) : '19.99'; ?>">
                        </div>
                        <div>
                            <label>سعر الخصم ($ — فارغ = بلا خصم)</label>
                            <input type="number" step="0.01" min="0" name="discount_price" value="<?php echo ($editGame && $editGame['discount_price'] !== null) ? e($editGame['discount_price']) : ''; ?>">
                        </div>
                        <div>
                            <label>التقييم (0 - 5)</label>
                            <input type="number" step="0.1" min="0" max="5" name="rating" value="<?php echo $editGame ? e($editGame['rating']) : '4.5'; ?>">
                        </div>
                        <div>
                            <label>التصنيف</label>
                            <select name="category">
                                <?php foreach ($categories as $value => $label) { ?>
                                    <option value="<?php echo e($value); ?>" <?php echo ($editGame && $editGame['category'] === $value) ? 'selected' : ''; ?>><?php echo e($label); ?></option>
                                <?php } ?>
                            </select>
                        </div>
                        <div>
                            <label>تاريخ الإصدار</label>
                            <input type="date" name="release_date" value="<?php echo $editGame ? e($editGame['release_date']) : '2024-01-01'; ?>">
                        </div>
                    </div>

                    <label>رابط صورة الغلاف (عمودية 600x900)</label>
                    <input type="url" name="image_url" value="<?php echo $editGame ? e($editGame['image_url']) : ''; ?>">

                    <label>رابط صورة البانر (عريضة library_hero)</label>
                    <input type="url" name="banner_url" value="<?php echo $editGame ? e($editGame['banner_url']) : ''; ?>">

                    <div class="check">
                        <input type="checkbox" name="is_featured" value="1" id="feat" <?php echo ($editGame && (int) $editGame['is_featured'] === 1) ? 'checked' : ''; ?>>
                        <label for="feat" style="margin:0;">لعبة مميزة (تظهر في البانر السينمائي)</label>
                    </div>

                    <button class="btn" type="submit"><?php echo $editGame ? 'حفظ التعديلات' : 'إضافة اللعبة'; ?></button>
                    <?php if ($editGame) { ?><a class="btn btn-ghost" href="admin.php" style="text-decoration:none;">إلغاء التعديل</a><?php } ?>
                </form>
            </div>

            <!-- جدول الألعاب -->
            <div class="card">
                <h2 style="font-size:16px; margin-bottom:12px;">الألعاب (<?php echo count($games); ?>)</h2>
                <div style="overflow-x:auto;">
                <table>
                    <tr>
                        <th>الغلاف</th>
                        <th>الاسم</th>
                        <th>التصنيف</th>
                        <th>السعر</th>
                        <th>التقييم</th>
                        <th>إجراءات</th>
                    </tr>
                    <?php foreach ($games as $g) {
                        $price    = (float) $g['price'];
                        $discount = $g['discount_price'] === null ? null : (float) $g['discount_price'];
                        $has      = $discount !== null && $discount < $price && $price > 0;
                    ?>
                    <tr>
                        <td>
                            <?php if ($g['image_url'] !== '') { ?>
                                <img src="<?php echo e($g['image_url']); ?>" alt="">
                            <?php } ?>
                        </td>
                        <td>
                            <?php echo e($g['name']); ?>
                            <?php if ((int) $g['is_featured'] === 1) { ?> <span class="tag">مميزة</span><?php } ?>
                        </td>
                        <td><?php echo isset($categories[$g['category']]) ? e($categories[$g['category']]) : e($g['category']); ?></td>
                        <td>
                            <?php if ($price <= 0) { ?>
                                <span class="tag tag-free">مجانية</span>
                            <?php } elseif ($has) { ?>
                                <span class="tag">-<?php echo (int) round((($price - $discount) / $price) * 100); ?>%</span>
                                <?php echo e(number_format($discount, 2)); ?>$
                            <?php } else { ?>
                                <?php echo e(number_format($price, 2)); ?>$
                            <?php } ?>
                        </td>
                        <td><?php echo e(number_format((float) $g['rating'], 1)); ?> ★</td>
                        <td>
                            <div class="actions">
                                <a class="btn-edit" href="admin.php?edit=<?php echo (int) $g['id']; ?>">تعديل</a>
                                <form method="post" action="admin.php" onsubmit="return confirm('تأكيد حذف: <?php echo e($g['name']); ?> ؟');">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="id" value="<?php echo (int) $g['id']; ?>">
                                    <button class="btn-danger" type="submit">حذف</button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    <?php } ?>
                </table>
                </div>
            </div>

            <a class="btn btn-ghost" href="?logout=1" style="text-decoration:none;">تسجيل الخروج</a>
        <?php } ?>
    <?php } ?>
</div>
</body>
</html>
