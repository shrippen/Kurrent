#!/usr/bin/env python3
"""Generate .po files for plasma_applet_com.github.shrippen.kurrent."""
from __future__ import annotations

import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extra_translations import EXTRA, EXTRA_PLURALS

DOMAIN = "plasma_applet_com.github.shrippen.kurrent"
YEAR = datetime.date.today().year

# msgid -> { lang: msgstr }  (empty lang value means copy msgid)
# Plural forms: msgid is the singular; msgstr_plural maps lang -> [singular, plural]
STRINGS: list[tuple[str, dict[str, str]]] = []


def add(msgid: str, **langs: str) -> None:
    STRINGS.append((msgid, langs))


# --- UI strings ---
add("Kurrent")
add("Task manager powered by Akonadi and Nextcloud CalDAV",
    zh_CN="基于 Akonadi 和 Nextcloud CalDAV 的任务管理器",
    hi="Akonadi और Nextcloud CalDAV पर आधारित कार्य प्रबंधक",
    es="Gestor de tareas con Akonadi y Nextcloud CalDAV",
    ar="مدير مهام يعتمد على Akonadi وNextcloud CalDAV",
    fr="Gestionnaire de tâches basé sur Akonadi et Nextcloud CalDAV",
    bn="Akonadi ও Nextcloud CalDAV ভিত্তিক টাস্ক ম্যানেজার",
    pt_BR="Gerenciador de tarefas com Akonadi e Nextcloud CalDAV",
    ru="Диспетчер задач на Akonadi и Nextcloud CalDAV",
    ur="Akonadi اور Nextcloud CalDAV پر مبنی ٹاسک مینیجر")
add("Inbox", zh_CN="收件箱", hi="इनबॉक्स", es="Bandeja de entrada", ar="الوارد",
    fr="Boîte de réception", bn="ইনবক্স", pt_BR="Caixa de entrada", ru="Входящие", ur="ان باکس")
add("Today", zh_CN="今天", hi="आज", es="Hoy", ar="اليوم", fr="Aujourd’hui", bn="আজ", pt_BR="Hoje", ru="Сегодня", ur="آج")
add("Overdue",
    zh_CN="已逾期", hi="अतिदेय", es="Atrasadas", ar="متأخرة", fr="En retard",
    bn="বকেয়া", pt_BR="Atrasadas", ru="Просрочено", ur="واجب الادا", ja="期限切れ")
add("Tomorrow", zh_CN="明天", hi="कल", es="Mañana", ar="غدًا", fr="Demain", bn="আগামীকাল", pt_BR="Amanhã", ru="Завтра", ur="کل")
add("Scheduled", zh_CN="已安排", hi="निर्धारित", es="Programadas", ar="مجدولة", fr="Planifiées", bn="নির্ধারিত", pt_BR="Agendadas", ru="Запланировано", ur="شیڈول شدہ")
add("Anytime", zh_CN="随时", hi="कभी भी", es="En cualquier momento", ar="في أي وقت", fr="À tout moment", bn="যেকোনো সময়", pt_BR="Quando quiser", ru="Когда угодно", ur="کسی بھی وقت")
add("Recurring", zh_CN="重复", hi="आवर्ती", es="Recurrentes", ar="متكررة", fr="Récurrentes", bn="পুনরাবৃত্ত", pt_BR="Recorrentes", ru="Повторяющиеся", ur="تکراری")
add("Unlabeled", zh_CN="无标签", hi="बिना लेबल", es="Sin etiqueta", ar="بدون وسم", fr="Sans étiquette", bn="লেবেলহীন", pt_BR="Sem etiqueta", ru="Без метки", ur="بغیر لیبل")
add("Completed", zh_CN="已完成", hi="पूर्ण", es="Completadas", ar="مكتملة", fr="Terminées", bn="সম্পন্ন", pt_BR="Concluídas", ru="Завершено", ur="مکمل")
add("No open tasks", zh_CN="没有未完成任务", hi="कोई खुला कार्य नहीं", es="No hay tareas abiertas", ar="لا مهام مفتوحة",
    fr="Aucune tâche ouverte", bn="কোনো খোলা কাজ নেই", pt_BR="Nenhuma tarefa aberta", ru="Нет открытых задач", ur="کوئی کھلا کام نہیں")
add("Due date", zh_CN="截止日期", hi="नियत तिथि", es="Fecha de vencimiento", ar="تاريخ الاستحقاق",
    fr="Date d’échéance", bn="নির্ধারিত তারিখ", pt_BR="Data de vencimento", ru="Срок", ur="مقررہ تاریخ")
add("Priority", zh_CN="优先级", hi="प्राथमिकता", es="Prioridad", ar="الأولوية", fr="Priorité", bn="অগ্রাধিকার", pt_BR="Prioridade", ru="Приоритет", ur="ترجیح")
add("Title A–Z", zh_CN="标题 A–Z", hi="शीर्षक A–Z", es="Título A–Z", ar="العنوان أ–ي", fr="Titre A–Z", bn="শিরোনাম A–Z", pt_BR="Título A–Z", ru="Название А–Я", ur="عنوان A–Z")
add("Title Z–A", zh_CN="标题 Z–A", hi="शीर्षक Z–A", es="Título Z–A", ar="العنوان ي–أ", fr="Titre Z–A", bn="শিরোনাম Z–A", pt_BR="Título Z–A", ru="Название Я–А", ur="عنوان Z–A")
add("Default", zh_CN="默认", hi="डिफ़ॉल्ट", es="Predeterminado", ar="افتراضي", fr="Par défaut", bn="ডিফল্ট", pt_BR="Padrão", ru="По умолчанию", ur="طے شدہ")
add("Sort: %1", zh_CN="排序：%1", hi="क्रम: %1", es="Orden: %1", ar="الترتيب: %1", fr="Tri : %1", bn="সাজানো: %1", pt_BR="Ordenar: %1", ru="Сортировка: %1", ur="ترتیب: %1")
add("Sort tasks", zh_CN="排序任务", hi="कार्य क्रमबद्ध करें", es="Ordenar tareas", ar="ترتيب المهام", fr="Trier les tâches", bn="কাজ সাজান", pt_BR="Ordenar tarefas", ru="Сортировать задачи", ur="کام ترتیب دیں")
add("First sort", zh_CN="第一排序", es="Primera ordenación", fr="Premier tri", ja="第1ソート")
add("Second sort", zh_CN="第二排序", es="Segunda ordenación", fr="Deuxième tri", ja="第2ソート")
add("Third sort", zh_CN="第三排序", es="Tercera ordenación", fr="Troisième tri", ja="第3ソート")
add("Open first", zh_CN="未完成优先", es="Abiertas primero", fr="Ouvertes d’abord", ja="未完了優先")
add("Build", zh_CN="构建", hi="बिल्ड", es="Compilación", ar="الإصدار", fr="Build", bn="বিল্ড", pt_BR="Build", ru="Сборка", ur="بلڈ")
add("Akonadi offline", zh_CN="Akonadi 离线", hi="Akonadi ऑफ़लाइन", es="Akonadi desconectado", ar="Akonadi غير متصل",
    fr="Akonadi hors ligne", bn="Akonadi অফলাইন", pt_BR="Akonadi offline", ru="Akonadi не в сети", ur="Akonadi آف لائن")
add("(Untitled)", zh_CN="（无标题）", hi="(शीर्षकहीन)", es="(Sin título)", ar="(بدون عنوان)", fr="(Sans titre)", bn="(শিরোনামহীন)", pt_BR="(Sem título)", ru="(Без названия)", ur="(بغیر عنوان)")
add("Projects", zh_CN="项目", hi="प्रोजेक्ट", es="Proyectos", ar="المشاريع", fr="Projets", bn="প্রকল্প", pt_BR="Projetos", ru="Проекты", ur="پروجیکٹس")
add("All", zh_CN="全部", hi="सभी", es="Todos", ar="الكل", fr="Tous", bn="সব", pt_BR="Todos", ru="Все", ur="سب")
add("Already in project “%1”", zh_CN="已在项目“%1”中", hi="पहले से प्रोजेक्ट “%1” में", es="Ya está en el proyecto “%1”",
    ar="موجود بالفعل في المشروع “%1”", fr="Déjà dans le projet « %1 »", bn="ইতিমধ্যে প্রকল্প “%1”-এ",
    pt_BR="Já está no projeto “%1”", ru="Уже в проекте «%1»", ur="پہلے سے پروجیکٹ “%1” میں")
add("Move to project “%1”", zh_CN="移动到项目“%1”", hi="प्रोजेक्ट “%1” में ले जाएँ", es="Mover al proyecto “%1”",
    ar="نقل إلى المشروع “%1”", fr="Déplacer vers le projet « %1 »", bn="প্রকল্প “%1”-এ সরান",
    pt_BR="Mover para o projeto “%1”", ru="Переместить в проект «%1»", ur="پروجیکٹ “%1” میں منتقل کریں")
add("Labels", zh_CN="标签", hi="लेबल", es="Etiquetas", ar="الوسوم", fr="Étiquettes", bn="লেবেল", pt_BR="Etiquetas", ru="Метки", ur="لیبلز")
add("Add label “%1”", zh_CN="添加标签“%1”", hi="लेबल “%1” जोड़ें", es="Añadir etiqueta “%1”", ar="إضافة الوسم “%1”",
    fr="Ajouter l’étiquette « %1 »", bn="লেবেল “%1” যোগ করুন", pt_BR="Adicionar etiqueta “%1”",
    ru="Добавить метку «%1»", ur="لیبل “%1” شامل کریں")
add("Search tasks…", zh_CN="搜索任务…", hi="कार्य खोजें…", es="Buscar tareas…", ar="البحث عن مهام…",
    fr="Rechercher des tâches…", bn="কাজ খুঁজুন…", pt_BR="Pesquisar tarefas…", ru="Поиск задач…", ur="کام تلاش کریں…")
add("Clear search", zh_CN="清除搜索", hi="खोज साफ़ करें", es="Borrar búsqueda", ar="مسح البحث",
    fr="Effacer la recherche", bn="অনুসন্ধান মুছুন", pt_BR="Limpar pesquisa", ru="Очистить поиск", ur="تلاش صاف کریں")
add("Exit delete mode", zh_CN="退出删除模式", hi="हटाने का मोड बंद करें", es="Salir del modo eliminar", ar="الخروج من وضع الحذف",
    fr="Quitter le mode suppression", bn="মুছার মোড থেকে বেরোন", pt_BR="Sair do modo de exclusão", ru="Выйти из режима удаления", ur="حذف موڈ سے باہر نکلیں")
add("Delete mode", zh_CN="删除模式", hi="हटाने का मोड", es="Modo eliminar", ar="وضع الحذف", fr="Mode suppression", bn="মুছার মোড", pt_BR="Modo de exclusão", ru="Режим удаления", ur="حذف موڈ")
add("Sync now", zh_CN="立即同步", hi="अभी सिंक करें", es="Sincronizar ahora", ar="مزامنة الآن", fr="Synchroniser maintenant", bn="এখনই সিঙ্ক করুন", pt_BR="Sincronizar agora", ru="Синхронизировать", ur="ابھی سنک کریں")
add("No tasks in this view.", zh_CN="此视图中没有任务。", hi="इस दृश्य में कोई कार्य नहीं।", es="No hay tareas en esta vista.",
    ar="لا مهام في هذا العرض.", fr="Aucune tâche dans cette vue.", bn="এই ভিউতে কোনো কাজ নেই।",
    pt_BR="Nenhuma tarefa nesta visualização.", ru="В этом представлении нет задач.", ur="اس منظر میں کوئی کام نہیں۔")
add("Make top-level task", zh_CN="设为顶级任务", hi="शीर्ष-स्तरीय कार्य बनाएँ", es="Convertir en tarea principal",
    ar="جعلها مهمة رئيسية", fr="En faire une tâche principale", bn="শীর্ষ-স্তরের কাজ করুন",
    pt_BR="Tornar tarefa principal", ru="Сделать задачей верхнего уровня", ur="اوپر کی سطح کا کام بنائیں")
add("Drop here to make a top-level task", zh_CN="拖到此处设为顶级任务", hi="शीर्ष-स्तरीय कार्य बनाने के लिए यहाँ छोड़ें",
    es="Suelta aquí para convertirla en tarea principal", ar="أفلت هنا لجعلها مهمة رئيسية",
    fr="Déposez ici pour en faire une tâche principale", bn="শীর্ষ-স্তরের কাজ করতে এখানে ছাড়ুন",
    pt_BR="Solte aqui para tornar a tarefa principal", ru="Отпустите здесь, чтобы сделать задачу верхней",
    ur="اوپر کی سطح کا کام بنانے کے لیے یہاں چھوڑیں")
add("Add a task…", zh_CN="添加任务…", hi="कार्य जोड़ें…", es="Añadir una tarea…", ar="إضافة مهمة…",
    fr="Ajouter une tâche…", bn="একটি কাজ যোগ করুন…", pt_BR="Adicionar uma tarefa…", ru="Добавить задачу…", ur="ایک کام شامل کریں…")
add("Add a task…  tomorrow 18:00 !high #tag @project",
    zh_CN="添加任务…  tomorrow 18:00 !high #tag @project",
    es="Añadir una tarea…  tomorrow 18:00 !high #tag @project",
    fr="Ajouter une tâche…  tomorrow 18:00 !high #tag @project")
add("Yesterday", zh_CN="昨天", es="Ayer", fr="Hier", ja="昨日")
add("Next week", zh_CN="下周", es="Próxima semana", fr="Semaine prochaine", ja="来週")
add("Tonight", zh_CN="今晚", es="Esta noche", fr="Ce soir", ja="今夜")
add("No priority", zh_CN="无优先级", es="Sin prioridad", fr="Sans priorité", ja="優先度なし")
add("Backend not installed",
    zh_CN="未安装后端", es="Motor no instalado", fr="Moteur non installé", ja="バックエンドが未インストール")
add("The KDE Store package is only the widget. Run this in a terminal to install the plugin:",
    zh_CN="KDE 商店安装包只有部件界面。在终端运行下面的命令以安装插件：",
    es="El paquete de KDE Store es solo el widget. Ejecuta esto en una terminal para instalar el complemento:",
    fr="Le paquet KDE Store n’est que le widget. Exécutez ceci dans un terminal pour installer le greffon :")
add("Copy command", zh_CN="复制命令", es="Copiar comando", fr="Copier la commande", ja="コマンドをコピー")
add("Open GitHub", zh_CN="打开 GitHub", es="Abrir GitHub", fr="Ouvrir GitHub", ja="GitHub を開く")
add("Add task", zh_CN="添加任务", hi="कार्य जोड़ें", es="Añadir tarea", ar="إضافة مهمة", fr="Ajouter une tâche", bn="কাজ যোগ করুন", pt_BR="Adicionar tarefa", ru="Добавить задачу", ur="کام شامل کریں")
add("Make subtask of “%1”", zh_CN="设为“%1”的子任务", hi="“%1” का उपकार्य बनाएँ", es="Convertir en subtarea de “%1”",
    ar="جعلها مهمة فرعية لـ “%1”", fr="En faire une sous-tâche de « %1 »", bn="“%1”-এর সাবটাস্ক করুন",
    pt_BR="Tornar subtarefa de “%1”", ru="Сделать подзадачей «%1»", ur="“%1” کا ذیلی کام بنائیں")
add("High priority (%1)", zh_CN="高优先级 (%1)", hi="उच्च प्राथमिकता (%1)", es="Prioridad alta (%1)", ar="أولوية عالية (%1)",
    fr="Priorité haute (%1)", bn="উচ্চ অগ্রাধিকার (%1)", pt_BR="Prioridade alta (%1)", ru="Высокий приоритет (%1)", ur="اعلی ترجیح (%1)")
add("Medium priority (%1)", zh_CN="中优先级 (%1)", hi="मध्यम प्राथमिकता (%1)", es="Prioridad media (%1)", ar="أولوية متوسطة (%1)",
    fr="Priorité moyenne (%1)", bn="মাঝারি অগ্রাধিকার (%1)", pt_BR="Prioridade média (%1)", ru="Средний приоритет (%1)", ur="درمیانی ترجیح (%1)")
add("Low priority (%1)", zh_CN="低优先级 (%1)", hi="निम्न प्राथमिकता (%1)", es="Prioridad baja (%1)", ar="أولوية منخفضة (%1)",
    fr="Priorité basse (%1)", bn="নিম্ন অগ্রাধিকার (%1)", pt_BR="Prioridade baixa (%1)", ru="Низкий приоритет (%1)", ur="کم ترجیح (%1)")
add("Priority %1", zh_CN="优先级 %1", hi="प्राथमिकता %1", es="Prioridad %1", ar="الأولوية %1", fr="Priorité %1", bn="অগ্রাধিকার %1", pt_BR="Prioridade %1", ru="Приоритет %1", ur="ترجیح %1")
add("Edit task", zh_CN="编辑任务", hi="कार्य संपादित करें", es="Editar tarea", ar="تحرير المهمة", fr="Modifier la tâche", bn="কাজ সম্পাদনা", pt_BR="Editar tarefa", ru="Изменить задачу", ur="کام ترمیم کریں")
add("Delete task", zh_CN="删除任务", hi="कार्य हटाएँ", es="Eliminar tarea", ar="حذف المهمة", fr="Supprimer la tâche", bn="কাজ মুছুন", pt_BR="Excluir tarefa", ru="Удалить задачу", ur="کام حذف کریں")
add("Waiting for Akonadi…", zh_CN="正在等待 Akonadi…", hi="Akonadi की प्रतीक्षा…", es="Esperando a Akonadi…", ar="بانتظار Akonadi…",
    fr="En attente d’Akonadi…", bn="Akonadi-এর অপেক্ষা…", pt_BR="Aguardando o Akonadi…", ru="Ожидание Akonadi…", ur="Akonadi کا انتظار…")
add("Basics", zh_CN="基本信息", hi="मूल बातें", es="Básicos", ar="الأساسيات", fr="Général", bn="মৌলিক", pt_BR="Básico", ru="Основное", ur="بنیادی")
add("Title:", zh_CN="标题：", hi="शीर्षक:", es="Título:", ar="العنوان:", fr="Titre :", bn="শিরোনাম:", pt_BR="Título:", ru="Название:", ur="عنوان:")
add("Title", zh_CN="标题", hi="शीर्षक", es="Título", ar="العنوان", fr="Titre", bn="শিরোনাম", pt_BR="Título", ru="Название", ur="عنوان")
add("Description:", zh_CN="描述：", hi="विवरण:", es="Descripción:", ar="الوصف:", fr="Description :", bn="বিবরণ:", pt_BR="Descrição:", ru="Описание:", ur="تفصیل:")
add("Description", zh_CN="描述", hi="विवरण", es="Descripción", ar="الوصف", fr="Description", bn="বিবরণ", pt_BR="Descrição", ru="Описание", ur="تفصیل")
add("Schedule", zh_CN="日程", hi="अनुसूची", es="Programación", ar="الجدول", fr="Planning", bn="সময়সূচি", pt_BR="Agenda", ru="Расписание", ur="شیڈول")
add("All day:", zh_CN="全天：", hi="पूरा दिन:", es="Todo el día:", ar="طوال اليوم:", fr="Journée entière :", bn="সারাদিন:", pt_BR="Dia inteiro:", ru="Весь день:", ur="پورے دن:")
add("All-day task", zh_CN="全天任务", hi="पूरे दिन का कार्य", es="Tarea de todo el día", ar="مهمة طوال اليوم",
    fr="Tâche sur toute la journée", bn="সারাদিনের কাজ", pt_BR="Tarefa de dia inteiro", ru="Задача на весь день", ur="پورے دن کا کام")
add("Start:", zh_CN="开始：", hi="प्रारंभ:", es="Inicio:", ar="البداية:", fr="Début :", bn="শুরু:", pt_BR="Início:", ru="Начало:", ur="شروع:")
add("Clear start", zh_CN="清除开始时间", hi="प्रारंभ साफ़ करें", es="Borrar inicio", ar="مسح البداية", fr="Effacer le début", bn="শুরু মুছুন", pt_BR="Limpar início", ru="Очистить начало", ur="شروع صاف کریں")
add("Due:", zh_CN="截止：", hi="नियत:", es="Vencimiento:", ar="الاستحقاق:", fr="Échéance :", bn="নির্ধারিত:", pt_BR="Vencimento:", ru="Срок:", ur="مقررہ:")
add("Clear due date", zh_CN="清除截止日期", hi="नियत तिथि साफ़ करें", es="Borrar fecha de vencimiento", ar="مسح تاريخ الاستحقاق",
    fr="Effacer la date d’échéance", bn="নির্ধারিত তারিখ মুছুন", pt_BR="Limpar data de vencimento", ru="Очистить срок", ur="مقررہ تاریخ صاف کریں")
add("Repeat:", zh_CN="重复：", hi="दोहराएँ:", es="Repetir:", ar="التكرار:", fr="Répéter :", bn="পুনরাবৃত্তি:", pt_BR="Repetir:", ru="Повтор:", ur="دہرائیں:")
add("None", zh_CN="无", hi="कोई नहीं", es="Ninguno", ar="لا شيء", fr="Aucun", bn="কোনোটি নয়", pt_BR="Nenhum", ru="Нет", ur="کوئی نہیں")
add("Daily", zh_CN="每天", hi="दैनिक", es="Diario", ar="يوميًا", fr="Quotidien", bn="দৈনিক", pt_BR="Diário", ru="Ежедневно", ur="روزانہ")
add("Weekly", zh_CN="每周", hi="साप्ताहिक", es="Semanal", ar="أسبوعيًا", fr="Hebdomadaire", bn="সাপ্তাহিক", pt_BR="Semanal", ru="Еженедельно", ur="ہفتہ وار")
add("Monthly", zh_CN="每月", hi="मासिक", es="Mensual", ar="شهريًا", fr="Mensuel", bn="মাসিক", pt_BR="Mensal", ru="Ежемесячно", ur="ماہانہ")
add("Yearly", zh_CN="每年", hi="वार्षिक", es="Anual", ar="سنويًا", fr="Annuel", bn="বার্ষিক", pt_BR="Anual", ru="Ежегодно", ur="سالانہ")
add("Status", zh_CN="状态", hi="स्थिति", es="Estado", ar="الحالة", fr="Statut", bn="অবস্থা", pt_BR="Status", ru="Статус", ur="حیثیت")
add("Completed:", zh_CN="已完成：", hi="पूर्ण:", es="Completada:", ar="مكتملة:", fr="Terminée :", bn="সম্পন্ন:", pt_BR="Concluída:", ru="Завершена:", ur="مکمل:")
add("Mark as done", zh_CN="标记为完成", hi="पूर्ण के रूप में चिह्नित करें", es="Marcar como hecha", ar="تعيين كمكتملة",
    fr="Marquer comme terminée", bn="সম্পন্ন হিসেবে চিহ্নিত করুন", pt_BR="Marcar como concluída", ru="Отметить как выполненную", ur="مکمل نشان زد کریں")
add("Progress:", zh_CN="进度：", hi="प्रगति:", es="Progreso:", ar="التقدم:", fr="Progression :", bn="অগ্রগতি:", pt_BR="Progresso:", ru="Прогресс:", ur="پیش رفت:")
add("Status:", zh_CN="状态：", hi="स्थिति:", es="Estado:", ar="الحالة:", fr="Statut :", bn="অবস্থা:", pt_BR="Status:", ru="Статус:", ur="حیثیت:")
add("Needs action", zh_CN="需要处理", hi="कार्रवाई आवश्यक", es="Requiere acción", ar="يحتاج إجراء", fr="Action requise", bn="কাজ প্রয়োজন", pt_BR="Requer ação", ru="Требует действий", ur="عمل درکار")
add("In process", zh_CN="进行中", hi="प्रगति पर", es="En proceso", ar="قيد التنفيذ", fr="En cours", bn="চলমান", pt_BR="Em andamento", ru="В процессе", ur="جاری")
add("Canceled", zh_CN="已取消", hi="रद्द", es="Cancelada", ar="ملغاة", fr="Annulée", bn="বাতিল", pt_BR="Cancelada", ru="Отменено", ur="منسوخ")
add("Classification", zh_CN="分类", hi="वर्गीकरण", es="Clasificación", ar="التصنيف", fr="Classification", bn="শ্রেণিবিন্যাস", pt_BR="Classificação", ru="Классификация", ur="درجہ بندی")
add("Priority:", zh_CN="优先级：", hi="प्राथमिकता:", es="Prioridad:", ar="الأولوية:", fr="Priorité :", bn="অগ্রাধিকার:", pt_BR="Prioridade:", ru="Приоритет:", ur="ترجیح:")
add("Labels:", zh_CN="标签：", hi="लेबल:", es="Etiquetas:", ar="الوسوم:", fr="Étiquettes :", bn="লেবেল:", pt_BR="Etiquetas:", ru="Метки:", ur="لیبلز:")
add("Secrecy:", zh_CN="保密：", hi="गोपनीयता:", es="Confidencialidad:", ar="السرية:", fr="Confidentialité :", bn="গোপনীয়তা:", pt_BR="Sigilo:", ru="Секретность:", ur="رازداری:")
add("Public", zh_CN="公开", hi="सार्वजनिक", es="Público", ar="عام", fr="Public", bn="সর্বজনীন", pt_BR="Público", ru="Открыто", ur="عوامی")
add("Private", zh_CN="私密", hi="निजी", es="Privado", ar="خاص", fr="Privé", bn="ব্যক্তিগত", pt_BR="Privado", ru="Личное", ur="نجی")
add("Confidential", zh_CN="机密", hi="गोपनीय", es="Confidencial", ar="سري", fr="Confidentiel", bn="গোপন", pt_BR="Confidencial", ru="Конфиденциально", ur="خفیہ")
add("Location:", zh_CN="地点：", hi="स्थान:", es="Ubicación:", ar="الموقع:", fr="Lieu :", bn="অবস্থান:", pt_BR="Local:", ru="Место:", ur="مقام:")
add("Location", zh_CN="地点", hi="स्थान", es="Ubicación", ar="الموقع", fr="Lieu", bn="অবস্থান", pt_BR="Local", ru="Место", ur="مقام")
add("Project:", zh_CN="项目：", hi="प्रोजेक्ट:", es="Proyecto:", ar="المشروع:", fr="Projet :", bn="প্রকল্প:", pt_BR="Projeto:", ru="Проект:", ur="پروجیکٹ:")
add("Parent:", zh_CN="父任务：", es="Padre:", fr="Parent :", ja="親:")
add("Open / Join", zh_CN="打开 / 加入", es="Abrir / Unirse", fr="Ouvrir / Rejoindre", ja="開く / 参加")
add("No projects available", zh_CN="没有可用项目", hi="कोई प्रोजेक्ट उपलब्ध नहीं", es="No hay proyectos disponibles",
    ar="لا مشاريع متاحة", fr="Aucun projet disponible", bn="কোনো প্রকল্প নেই", pt_BR="Nenhum projeto disponível",
    ru="Нет доступных проектов", ur="کوئی پروجیکٹ دستیاب نہیں")
add("Pick date", zh_CN="选择日期", hi="तिथि चुनें", es="Elegir fecha", ar="اختيار التاريخ", fr="Choisir une date", bn="তারিখ বেছে নিন", pt_BR="Escolher data", ru="Выбрать дату", ur="تاریخ منتخب کریں")
add("Due", zh_CN="截止", hi="नियत", es="Vencimiento", ar="الاستحقاق", fr="Échéance", bn="নির্ধারিত", pt_BR="Vencimento", ru="Срок", ur="مقررہ")
add("All day", zh_CN="全天", hi="पूरा दिन", es="Todo el día", ar="طوال اليوم", fr="Journée entière", bn="সারাদিন", pt_BR="Dia inteiro", ru="Весь день", ur="پورے دن")
add("Cancel", zh_CN="取消", hi="रद्द करें", es="Cancelar", ar="إلغاء", fr="Annuler", bn="বাতিল", pt_BR="Cancelar", ru="Отмена", ur="منسوخ")
add("More…", zh_CN="更多…", hi="और…", es="Más…", ar="المزيد…", fr="Plus…", bn="আরও…", pt_BR="Mais…", ru="Ещё…", ur="مزید…")
add("Save", zh_CN="保存", hi="सहेजें", es="Guardar", ar="حفظ", fr="Enregistrer", bn="সংরক্ষণ", pt_BR="Salvar", ru="Сохранить", ur="محفوظ کریں")
add("High", zh_CN="高", hi="उच्च", es="Alta", ar="عالية", fr="Haute", bn="উচ্চ", pt_BR="Alta", ru="Высокий", ur="اعلی")
add("Medium", zh_CN="中", hi="मध्यम", es="Media", ar="متوسطة", fr="Moyenne", bn="মাঝারি", pt_BR="Média", ru="Средний", ur="درمیانہ")
add("Low", zh_CN="低", hi="निम्न", es="Baja", ar="منخفضة", fr="Basse", bn="নিম্ন", pt_BR="Baixa", ru="Низкий", ur="کم")
add("Search or create label…", zh_CN="搜索或创建标签…", hi="लेबल खोजें या बनाएँ…", es="Buscar o crear etiqueta…",
    ar="البحث عن وسم أو إنشاؤه…", fr="Rechercher ou créer une étiquette…", bn="লেবেল খুঁজুন বা তৈরি করুন…",
    pt_BR="Pesquisar ou criar etiqueta…", ru="Найти или создать метку…", ur="لیبل تلاش یا بنائیں…")
add("Search parent task…", zh_CN="搜索父任务…", es="Buscar tarea padre…", fr="Rechercher une tâche parente…", ja="親タスクを検索…")
add("Clear parent", zh_CN="清除父任务", es="Quitar padre", fr="Effacer le parent", ja="親をクリア")
add("No matching tasks", zh_CN="没有匹配的任务", es="No hay tareas coincidentes", fr="Aucune tâche correspondante", ja="一致するタスクがありません")
add("Remove label", zh_CN="移除标签", hi="लेबल हटाएँ", es="Quitar etiqueta", ar="إزالة الوسم", fr="Retirer l’étiquette", bn="লেবেল সরান", pt_BR="Remover etiqueta", ru="Убрать метку", ur="لیبل ہٹائیں")
add("Create label “%1”", zh_CN="创建标签“%1”", hi="लेबल “%1” बनाएँ", es="Crear etiqueta “%1”", ar="إنشاء الوسم “%1”",
    fr="Créer l’étiquette « %1 »", bn="লেবেল “%1” তৈরি করুন", pt_BR="Criar etiqueta “%1”", ru="Создать метку «%1»", ur="لیبل “%1” بنائیں")
add("No matching labels", zh_CN="没有匹配的标签", hi="कोई मेल खाता लेबल नहीं", es="No hay etiquetas coincidentes",
    ar="لا وسوم مطابقة", fr="Aucune étiquette correspondante", bn="কোনো মিল নেই", pt_BR="Nenhuma etiqueta correspondente",
    ru="Нет подходящих меток", ur="کوئی مماثل لیبل نہیں")
add("Select a label to filter tasks.", zh_CN="选择标签以筛选任务。", hi="कार्य फ़िल्टर करने के लिए लेबल चुनें।",
    es="Selecciona una etiqueta para filtrar tareas.", ar="اختر وسمًا لتصفية المهام.",
    fr="Sélectionnez une étiquette pour filtrer les tâches.", bn="কাজ ফিল্টার করতে একটি লেবেল বেছে নিন।",
    pt_BR="Selecione uma etiqueta para filtrar tarefas.", ru="Выберите метку, чтобы отфильтровать задачи.",
    ur="کام فلٹر کرنے کے لیے لیبل منتخب کریں۔")
add("Clear label filter", zh_CN="清除标签筛选", hi="लेबल फ़िल्टर साफ़ करें", es="Borrar filtro de etiqueta", ar="مسح عامل تصفية الوسم",
    fr="Effacer le filtre d’étiquette", bn="লেবেল ফিল্টার মুছুন", pt_BR="Limpar filtro de etiqueta", ru="Сбросить фильтр метки", ur="لیبل فلٹر صاف کریں")
add("Projects (Akonadi Calendars)", zh_CN="项目（Akonadi 日历）", hi="प्रोजेक्ट (Akonadi कैलेंडर)", es="Proyectos (calendarios Akonadi)",
    ar="المشاريع (تقويمات Akonadi)", fr="Projets (calendriers Akonadi)", bn="প্রকল্প (Akonadi ক্যালেন্ডার)",
    pt_BR="Projetos (calendários Akonadi)", ru="Проекты (календари Akonadi)", ur="پروجیکٹس (Akonadi کیلنڈرز)")
add("Manage which Akonadi calendars are used as projects. Disabled calendars are excluded from task fetching entirely. Hidden calendars are still fetched but not shown in the sidebar.",
    zh_CN="管理哪些 Akonadi 日历用作项目。禁用的日历完全不获取任务。隐藏的日历仍会获取，但不在侧栏显示。",
    hi="कौन से Akonadi कैलेंडर प्रोजेक्ट के रूप में उपयोग होंगे, प्रबंधित करें। अक्षम कैलेंडर से कार्य नहीं लाए जाते। छिपे कैलेंडर लाए जाते हैं पर साइडबार में नहीं दिखते।",
    es="Elige qué calendarios Akonadi se usan como proyectos. Los desactivados no se consultan. Los ocultos se consultan pero no aparecen en la barra lateral.",
    ar="أدر تقويمات Akonadi المستخدمة كمشاريع. التقويمات المعطلة لا تُجلب. المخفية تُجلب دون ظهورها في الشريط الجانبي.",
    fr="Choisissez les calendriers Akonadi utilisés comme projets. Les calendriers désactivés sont exclus. Les calendriers masqués sont chargés mais absents de la barre latérale.",
    bn="কোন Akonadi ক্যালেন্ডার প্রকল্প হিসেবে ব্যবহার হবে তা পরিচালনা করুন। নিষ্ক্রিয় ক্যালেন্ডার থেকে কাজ আনা হয় না। লুকানো ক্যালেন্ডার আনা হয় কিন্তু সাইডবারে দেখা যায় না।",
    pt_BR="Gerencie quais calendários Akonadi são usados como projetos. Calendários desativados não são consultados. Ocultos são consultados, mas não aparecem na barra lateral.",
    ru="Выберите календари Akonadi, используемые как проекты. Отключённые не загружаются. Скрытые загружаются, но не показываются в боковой панели.",
    ur="منتخب کریں کہ کون سے Akonadi کیلنڈر بطور پروجیکٹ استعمال ہوں۔ غیر فعال کیلنڈرز سے کام نہیں آتے۔ پوشیدہ کیلنڈرز آتے ہیں مگر سائیڈبار میں نہیں دکھتے۔")
add("No Akonadi calendars found. Make sure Akonadi is running.",
    zh_CN="未找到 Akonadi 日历。请确认 Akonadi 正在运行。",
    hi="कोई Akonadi कैलेंडर नहीं मिला। सुनिश्चित करें कि Akonadi चल रहा है।",
    es="No se encontraron calendarios Akonadi. Comprueba que Akonadi esté en ejecución.",
    ar="لم يُعثر على تقويمات Akonadi. تأكد أن Akonadi قيد التشغيل.",
    fr="Aucun calendrier Akonadi trouvé. Vérifiez qu’Akonadi est lancé.",
    bn="কোনো Akonadi ক্যালেন্ডার পাওয়া যায়নি। Akonadi চলছে কিনা দেখুন।",
    pt_BR="Nenhum calendário Akonadi encontrado. Verifique se o Akonadi está em execução.",
    ru="Календари Akonadi не найдены. Убедитесь, что Akonadi запущен.",
    ur="کوئی Akonadi کیلنڈر نہیں ملا۔ یقینی بنائیں کہ Akonadi چل رہا ہے۔")
add("Collection ID: %1", zh_CN="集合 ID：%1", hi="संग्रह ID: %1", es="ID de colección: %1", ar="معرّف المجموعة: %1",
    fr="ID de collection : %1", bn="সংগ্রহ ID: %1", pt_BR="ID da coleção: %1", ru="ID коллекции: %1", ur="مجموعہ ID: %1")
add("Enabled", zh_CN="已启用", hi="सक्षम", es="Activado", ar="مفعّل", fr="Activé", bn="সক্রিয়", pt_BR="Ativado", ru="Включено", ur="فعال")
add("Include this calendar when fetching tasks", zh_CN="获取任务时包含此日历", hi="कार्य लाते समय इस कैलेंडर को शामिल करें",
    es="Incluir este calendario al obtener tareas", ar="تضمين هذا التقويم عند جلب المهام",
    fr="Inclure ce calendrier lors du chargement des tâches", bn="কাজ আনার সময় এই ক্যালেন্ডার অন্তর্ভুক্ত করুন",
    pt_BR="Incluir este calendário ao buscar tarefas", ru="Включать этот календарь при загрузке задач",
    ur="کام لاتے وقت اس کیلنڈر کو شامل کریں")
add("Visible", zh_CN="可见", hi="दृश्यमान", es="Visible", ar="ظاهر", fr="Visible", bn="দৃশ্যমান", pt_BR="Visível", ru="Видимый", ur="نظر آنے والا")
add("Show this project in the sidebar", zh_CN="在侧栏显示此项目", hi="इस प्रोजेक्ट को साइडबार में दिखाएँ",
    es="Mostrar este proyecto en la barra lateral", ar="إظهار هذا المشروع في الشريط الجانبي",
    fr="Afficher ce projet dans la barre latérale", bn="সাইডবারে এই প্রকল্প দেখান",
    pt_BR="Mostrar este projeto na barra lateral", ru="Показывать этот проект в боковой панели",
    ur="اس پروجیکٹ کو سائیڈبار میں دکھائیں")
add("Enable All", zh_CN="全部启用", hi="सभी सक्षम करें", es="Activar todo", ar="تفعيل الكل", fr="Tout activer", bn="সব সক্রিয় করুন", pt_BR="Ativar todos", ru="Включить все", ur="سب فعال کریں")
add("Show All", zh_CN="全部显示", hi="सभी दिखाएँ", es="Mostrar todo", ar="إظهار الكل", fr="Tout afficher", bn="সব দেখান", pt_BR="Mostrar todos", ru="Показать все", ur="سب دکھائیں")
add("Refresh", zh_CN="刷新", hi="ताज़ा करें", es="Actualizar", ar="تحديث", fr="Actualiser", bn="রিফ্রেশ", pt_BR="Atualizar", ru="Обновить", ur="تازہ کریں")
add("Akonadi", zh_CN="Akonadi", hi="Akonadi", es="Akonadi", ar="Akonadi", fr="Akonadi", bn="Akonadi", pt_BR="Akonadi", ru="Akonadi", ur="Akonadi")
add("Tasks are loaded from your existing Akonadi setup.",
    zh_CN="任务来自您现有的 Akonadi 配置。", hi="कार्य आपके मौजूदा Akonadi सेटअप से लोड होते हैं।",
    es="Las tareas se cargan desde tu configuración Akonadi existente.",
    ar="تُحمَّل المهام من إعداد Akonadi الحالي.", fr="Les tâches sont chargées depuis votre configuration Akonadi.",
    bn="কাজ আপনার বিদ্যমান Akonadi সেটআপ থেকে লোড হয়।", pt_BR="As tarefas são carregadas da sua configuração Akonadi.",
    ru="Задачи загружаются из существующей настройки Akonadi.", ur="کام آپ کے موجودہ Akonadi سیٹ اپ سے لوڈ ہوتے ہیں۔")
add("Setup", zh_CN="设置", hi="सेटअप", es="Configuración", ar="الإعداد", fr="Configuration", bn="সেটআপ", pt_BR="Configuração", ru="Настройка", ur="سیٹ اپ")
add("Configure CalDAV/Nextcloud in KOrganizer or Kalendar (DAV groupware resource).",
    zh_CN="在 KOrganizer 或 Kalendar 中配置 CalDAV/Nextcloud（DAV 群件资源）。",
    hi="KOrganizer या Kalendar में CalDAV/Nextcloud कॉन्फ़िगर करें (DAV ग्रुपवेयर संसाधन)।",
    es="Configura CalDAV/Nextcloud en KOrganizer o Kalendar (recurso DAV groupware).",
    ar="اضبط CalDAV/Nextcloud في KOrganizer أو Kalendar (مورد DAV).",
    fr="Configurez CalDAV/Nextcloud dans KOrganizer ou Kalendar (ressource DAV).",
    bn="KOrganizer বা Kalendar-এ CalDAV/Nextcloud কনফিগার করুন (DAV গ্রুপওয়্যার রিসোর্স)।",
    pt_BR="Configure o CalDAV/Nextcloud no KOrganizer ou Kalendar (recurso DAV).",
    ru="Настройте CalDAV/Nextcloud в KOrganizer или Kalendar (ресурс DAV).",
    ur="KOrganizer یا Kalendar میں CalDAV/Nextcloud ترتیب دیں (DAV گروپ ویئر ریسورس)۔")
add("Default view", zh_CN="默认视图", hi="डिफ़ॉल्ट दृश्य", es="Vista predeterminada", ar="العرض الافتراضي",
    fr="Vue par défaut", bn="ডিফল্ট ভিউ", pt_BR="Visualização padrão", ru="Вид по умолчанию", ur="طے شدہ منظر")
add("Completed tasks", zh_CN="已完成任务", hi="पूर्ण कार्य", es="Tareas completadas", ar="المهام المكتملة",
    fr="Tâches terminées", bn="সম্পন্ন কাজ", pt_BR="Tarefas concluídas", ru="Завершённые задачи", ur="مکمل کام")
add("Show completed tasks", zh_CN="显示已完成任务", hi="पूर्ण कार्य दिखाएँ", es="Mostrar tareas completadas",
    ar="إظهار المهام المكتملة", fr="Afficher les tâches terminées", bn="সম্পন্ন কাজ দেখান",
    pt_BR="Mostrar tarefas concluídas", ru="Показывать завершённые задачи", ur="مکمل کام دکھائیں")
add("Appearance", zh_CN="外观", hi="दिखावट", es="Apariencia", ar="المظهر", fr="Apparence",
    bn="চেহারা", pt_BR="Aparência", ru="Внешний вид", ur="ظاہری شکل")
add("Blurred background", zh_CN="模糊背景", hi="धुंधला पृष्ठभूमि", es="Fondo desenfocado", ar="خلفية ضبابية",
    fr="Arrière-plan flou", bn="ঝাপসা পটভূমি", pt_BR="Fundo desfocado", ru="Размытый фон", ur="دھندلا پس منظر")
add("Use Plasma’s translucent background so KWin blurs the wallpaper. Also applies to the panel flyout.",
    zh_CN="使用 Plasma 半透明背景，让 KWin 模糊壁纸。同样作用于面板弹出窗口。",
    hi="Plasma का पारदर्शी पृष्ठभूमि उपयोग करें ताकि KWin वॉलपेपर ब्लर करे। पैनल फ्लायआउट पर भी लागू।",
    es="Usa el fondo translúcido de Plasma para que KWin desenfogue el fondo. También aplica al desplegable del panel.",
    ar="استخدم خلفية Plasma الشفافة ليُضبّب KWin الخلفية. ينطبق أيضًا على منبثقة اللوحة.",
    fr="Utilise le fond translucide de Plasma pour que KWin floute le fond d’écran. S’applique aussi au menu du panneau.",
    bn="Plasma-এর স্বচ্ছ ব্যাকগ্রাউন্ড ব্যবহার করুন যাতে KWin ওয়ালপেপার ব্লার করে। প্যানেল ফ্লাইআউটেও প্রযোজ্য।",
    pt_BR="Usa o fundo translúcido do Plasma para o KWin desfocar o papel de parede. Também vale para o flyout do painel.",
    ru="Полупрозрачный фон Plasma, чтобы KWin размывал обои. Также действует на всплывающее окно панели.",
    ur="Plasma کا شفاف پس منظر استعمال کریں تاکہ KWin وال پیپر بلر کرے۔ پینل فلائی آؤٹ پر بھی لاگو۔")
add("Sidebar row size", zh_CN="侧栏行高", hi="साइडबार पंक्ति आकार", es="Tamaño de filas de la barra lateral",
    ar="حجم صفوف الشريط الجانبي", fr="Taille des lignes de la barre latérale", bn="সাইডবার সারির আকার",
    pt_BR="Tamanho das linhas da barra lateral", ru="Размер строк боковой панели", ur="سائیڈبار قطار کا سائز")
add("Auto (compact, larger with touch)", zh_CN="自动（紧凑，触摸时更大）", hi="स्वतः (सघन, टच पर बड़ा)",
    es="Automático (compacto, más grande con tacto)", ar="تلقائي (مدمج، أكبر مع اللمس)",
    fr="Auto (compact, plus grand au tactile)", bn="স্বয়ংক্রিয় (কমপ্যাক্ট, টাচে বড়)",
    pt_BR="Automático (compacto, maior com toque)", ru="Авто (компактно, больше при касании)",
    ur="خودکار (کمپیکٹ، ٹچ پر بڑا)")
add("Compact", zh_CN="紧凑", hi="सघन", es="Compacto", ar="مدمج", fr="Compact", bn="কমপ্যাক্ট", pt_BR="Compacto", ru="Компактный", ur="کمپیکٹ")
add("Comfortable (touch-friendly)", zh_CN="舒适（适合触摸）", hi="आरामदायक (टच-अनुकूल)", es="Cómodo (táctil)",
    ar="مريح (مناسب للمس)", fr="Confortable (tactile)", bn="আরামদায়ক (টাচ-বান্ধব)",
    pt_BR="Confortável (toque)", ru="Удобный (для касаний)", ur="آرام دہ (ٹچ دوست)")
add("Auto uses compact rows on mouse/desktop and comfortable rows when Plasma detects tablet or touch input.",
    zh_CN="自动：鼠标/桌面用紧凑行，检测到平板或触摸时用舒适行。",
    hi="स्वतः माउस/डेस्कटॉप पर सघन पंक्तियाँ और टैबलेट/टच पर आरामदायक पंक्तियाँ उपयोग करता है।",
    es="Automático usa filas compactas con ratón y filas cómodas si Plasma detecta tableta o tacto.",
    ar="التلقائي يستخدم صفوفًا مدمجة مع الفأرة وصفوفًا مريحة عند اكتشاف اللوح أو اللمس.",
    fr="Auto utilise des lignes compactes à la souris et des lignes confortables si Plasma détecte une tablette ou un écran tactile.",
    bn="স্বয়ংক্রিয় মouses/ডেস্কটপে কমপ্যাক্ট সারি এবং ট্যাবলেট/টাচে আরামদায়ক সারি ব্যবহার করে।",
    pt_BR="O automático usa linhas compactas com mouse e linhas confortáveis se o Plasma detectar tablet ou toque.",
    ru="Авто: компактные строки с мышью и удобные, если Plasma обнаруживает планшет или касание.",
    ur="خودکار ماؤس/ڈیسک ٹاپ پر کمپیکٹ قطاریں اور ٹیبلیٹ/ٹچ پر آرام دہ قطاریں استعمال کرتا ہے۔")
add("New tasks", zh_CN="新任务", hi="नए कार्य", es="Tareas nuevas", ar="مهام جديدة",
    fr="Nouvelles tâches", bn="নতুন কাজ", pt_BR="Novas tarefas", ru="Новые задачи", ur="نئے کام")
add("Ask which project to use", zh_CN="询问使用哪个项目", hi="पूछें कि कौन सा प्रोजेक्ट उपयोग करें",
    es="Preguntar qué proyecto usar", ar="اسأل أي مشروع يُستخدم",
    fr="Demander quel projet utiliser", bn="কোন প্রকল্প ব্যবহার করবেন জিজ্ঞাসা করুন",
    pt_BR="Perguntar qual projeto usar", ru="Спрашивать, какой проект использовать",
    ur="پوچھیں کہ کون سا پروجیکٹ استعمال ہو")
add("Use the top project in the sidebar", zh_CN="使用侧栏中的第一个项目",
    hi="साइडबार का सबसे ऊपरी प्रोजेक्ट उपयोग करें",
    es="Usar el primer proyecto de la barra lateral", ar="استخدام أعلى مشروع في الشريط الجانبي",
    fr="Utiliser le premier projet de la barre latérale", bn="সাইডবারের উপরের প্রকল্প ব্যবহার করুন",
    pt_BR="Usar o primeiro projeto da barra lateral", ru="Использовать верхний проект в боковой панели",
    ur="سائیڈبار کا سب سے اوپر والا پروجیکٹ استعمال کریں")
add("Use a specific project", zh_CN="使用指定项目", hi="एक खास प्रोजेक्ट उपयोग करें",
    es="Usar un proyecto concreto", ar="استخدام مشروع محدد",
    fr="Utiliser un projet précis", bn="একটি নির্দিষ্ট প্রকল্প ব্যবহার করুন",
    pt_BR="Usar um projeto específico", ru="Использовать выбранный проект",
    ur="ایک مخصوص پروجیکٹ استعمال کریں")
add("When no project is selected in the sidebar, new tasks follow this setting.",
    zh_CN="未在侧栏选择项目时，新任务按此设置处理。",
    hi="जब साइडबार में कोई प्रोजेक्ट चुना न हो, नए कार्य इस सेटिंग का पालन करते हैं।",
    es="Si no hay un proyecto seleccionado en la barra lateral, las tareas nuevas siguen esta opción.",
    ar="عندما لا يُحدد مشروع في الشريط الجانبي، تتبع المهام الجديدة هذا الإعداد.",
    fr="Si aucun projet n’est sélectionné dans la barre latérale, les nouvelles tâches suivent ce réglage.",
    bn="সাইডবারে কোনো প্রকল্প না থাকলে নতুন কাজ এই সেটিং অনুসরণ করে।",
    pt_BR="Se nenhum projeto estiver selecionado na barra lateral, as novas tarefas seguem esta opção.",
    ru="Если в боковой панели не выбран проект, новые задачи следуют этой настройке.",
    ur="اگر سائیڈبار میں کوئی پروجیکٹ منتخب نہ ہو تو نئے کام اس ترتیب کی پیروی کرتے ہیں۔")
add("Default project", zh_CN="默认项目", hi="डिफ़ॉल्ट प्रोजेक्ट", es="Proyecto predeterminado",
    ar="المشروع الافتراضي", fr="Projet par défaut", bn="ডিফল্ট প্রকল্প",
    pt_BR="Projeto padrão", ru="Проект по умолчанию", ur="طے شدہ پروجیکٹ")
add("Choose a project", zh_CN="选择项目", hi="प्रोजेक्ट चुनें", es="Elegir un proyecto",
    ar="اختر مشروعًا", fr="Choisir un projet", bn="একটি প্রকল্প বেছে নিন",
    pt_BR="Escolher um projeto", ru="Выберите проект", ur="ایک پروجیکٹ منتخب کریں")
add("Choose a project for “%1”", zh_CN="为“%1”选择项目", hi="“%1” के लिए प्रोजेक्ट चुनें",
    es="Elegir un proyecto para “%1”", ar="اختر مشروعًا لـ “%1”",
    fr="Choisir un projet pour « %1 »", bn="“%1”-এর জন্য একটি প্রকল্প বেছে নিন",
    pt_BR="Escolher um projeto para “%1”", ru="Выберите проект для «%1»",
    ur="“%1” کے لیے پروجیکٹ منتخب کریں")
add("Labels (Categories)", zh_CN="标签（类别）", hi="लेबल (श्रेणियाँ)", es="Etiquetas (categorías)", ar="الوسوم (الفئات)",
    fr="Étiquettes (catégories)", bn="লেবেল (বিভাগ)", pt_BR="Etiquetas (categorias)", ru="Метки (категории)", ur="لیبلز (زمرے)")
add("Labels are extracted from Akonadi task categories. Hidden labels will not appear in the sidebar filter list but remain on tasks.",
    zh_CN="标签来自 Akonadi 任务类别。隐藏的标签不出现在侧栏筛选中，但仍保留在任务上。",
    hi="लेबल Akonadi कार्य श्रेणियों से लिए जाते हैं। छिपे लेबल साइडबार फ़िल्टर में नहीं दिखते, पर कार्यों पर रहते हैं।",
    es="Las etiquetas salen de las categorías de Akonadi. Las ocultas no aparecen en la barra lateral, pero siguen en las tareas.",
    ar="تُستخرج الوسوم من فئات مهام Akonadi. الوسوم المخفية لا تظهر في الشريط الجانبي لكنها تبقى على المهام.",
    fr="Les étiquettes proviennent des catégories Akonadi. Les étiquettes masquées n’apparaissent pas dans la barre latérale mais restent sur les tâches.",
    bn="লেবেল Akonadi কাজের বিভাগ থেকে আসে। লুকানো লেবেল সাইডবারে দেখা যায় না কিন্তু কাজে থাকে।",
    pt_BR="As etiquetas vêm das categorias Akonadi. Ocultas não aparecem na barra lateral, mas permanecem nas tarefas.",
    ru="Метки берутся из категорий задач Akonadi. Скрытые не показываются в боковой панели, но остаются на задачах.",
    ur="لیبلز Akonadi ٹاسک کیٹیگریز سے آتے ہیں۔ پوشیدہ لیبلز سائیڈبار میں نہیں دکھتے مگر کاموں پر رہتے ہیں۔")
add("No labels found. Labels are automatically discovered from task categories in Akonadi.",
    zh_CN="未找到标签。标签会从 Akonadi 任务类别自动发现。",
    hi="कोई लेबल नहीं मिला। लेबल Akonadi कार्य श्रेणियों से स्वतः मिलते हैं।",
    es="No se encontraron etiquetas. Se descubren automáticamente desde las categorías de Akonadi.",
    ar="لم يُعثر على وسوم. تُكتشف تلقائيًا من فئات مهام Akonadi.",
    fr="Aucune étiquette trouvée. Elles sont découvertes automatiquement depuis les catégories Akonadi.",
    bn="কোনো লেবেল পাওয়া যায়নি। Akonadi কাজের বিভাগ থেকে স্বয়ংক্রিয়ভাবে পাওয়া যায়।",
    pt_BR="Nenhuma etiqueta encontrada. Elas são descobertas automaticamente nas categorias Akonadi.",
    ru="Метки не найдены. Они обнаруживаются автоматически из категорий Akonadi.",
    ur="کوئی لیبل نہیں ملا۔ وہ Akonadi کیٹیگریز سے خود دریافت ہوتے ہیں۔")
add("Auto-generated color for '%1'", zh_CN="“%1”的自动颜色", hi="'%1' के लिए स्वतः रंग", es="Color generado automáticamente para «%1»",
    ar="لون مُولَّد تلقائيًا لـ '%1'", fr="Couleur générée automatiquement pour « %1 »",
    bn="'%1'-এর স্বয়ংক্রিয় রং", pt_BR="Cor gerada automaticamente para '%1'", ru="Автоцвет для «%1»", ur="'%1' کا خودکار رنگ")
add("Show this label in the sidebar filter", zh_CN="在侧栏筛选中显示此标签", hi="इस लेबल को साइडबार फ़िल्टर में दिखाएँ",
    es="Mostrar esta etiqueta en el filtro de la barra lateral", ar="إظهار هذا الوسم في تصفية الشريط الجانبي",
    fr="Afficher cette étiquette dans le filtre de la barre latérale", bn="সাইডবার ফিল্টারে এই লেবেল দেখান",
    pt_BR="Mostrar esta etiqueta no filtro da barra lateral", ru="Показывать эту метку в фильтре боковой панели",
    ur="اس لیبل کو سائیڈبار فلٹر میں دکھائیں")
add("General", zh_CN="常规", hi="सामान्य", es="General", ar="عام", fr="Général", bn="সাধারণ", pt_BR="Geral", ru="Основные", ur="عمومی")
add("Select a project to filter tasks.", zh_CN="选择项目以筛选任务。", hi="कार्य फ़िल्टर करने के लिए प्रोजेक्ट चुनें।",
    es="Selecciona un proyecto para filtrar tareas.", ar="اختر مشروعًا لتصفية المهام.",
    fr="Sélectionnez un projet pour filtrer les tâches.", bn="কাজ ফিল্টার করতে একটি প্রকল্প বেছে নিন।",
    pt_BR="Selecione um projeto para filtrar tarefas.", ru="Выберите проект, чтобы отфильтровать задачи.",
    ur="کام فلٹر کرنے کے لیے پروجیکٹ منتخب کریں۔")
add("Clear project filter", zh_CN="清除项目筛选", hi="प्रोजेक्ट फ़िल्टर साफ़ करें", es="Borrar filtro de proyecto",
    ar="مسح عامل تصفية المشروع", fr="Effacer le filtre de projet", bn="প্রকল্প ফিল্টার মুছুন",
    pt_BR="Limpar filtro de projeto", ru="Сбросить фильтр проекта", ur="پروجیکٹ فلٹر صاف کریں")
add("Priorities", zh_CN="优先级", es="Prioridades", fr="Priorités", ja="優先度")
add("Set priority “%1”", zh_CN="将优先级设为“%1”", es="Establecer prioridad “%1”", fr="Définir la priorité « %1 »", ja="優先度を「%1」に設定")
add("Already priority “%1”", zh_CN="已是优先级“%1”", es="Ya tiene prioridad “%1”", fr="Déjà priorité « %1 »", ja="すでに優先度「%1」")
add("Clear priority", zh_CN="清除优先级", es="Quitar prioridad", fr="Effacer la priorité", ja="優先度を解除")
add("Already has no priority", zh_CN="已无优先级", es="Ya no tiene prioridad", fr="Déjà sans priorité", ja="すでに優先度なし")
add("Due date, then priority", zh_CN="先截止日期，再优先级", es="Fecha de vencimiento, luego prioridad", fr="Date d’échéance, puis priorité", ja="期限、次に優先度")
add("Due date, then title", zh_CN="先截止日期，再标题", es="Fecha de vencimiento, luego título", fr="Date d’échéance, puis titre", ja="期限、次にタイトル")
add("Priority, then due date", zh_CN="先优先级，再截止日期", es="Prioridad, luego fecha de vencimiento", fr="Priorité, puis date d’échéance", ja="優先度、次に期限")
add("Priority, then title", zh_CN="先优先级，再标题", es="Prioridad, luego título", fr="Priorité, puis titre", ja="優先度、次にタイトル")
add("Open first, then due date", zh_CN="先未完成，再截止日期", es="Abiertas primero, luego fecha", fr="Ouvertes d’abord, puis échéance", ja="未完了優先、次に期限")
add("Open first, then priority", zh_CN="先未完成，再优先级", es="Abiertas primero, luego prioridad", fr="Ouvertes d’abord, puis priorité", ja="未完了優先、次に優先度")
add("New label", zh_CN="新标签", es="Nueva etiqueta", fr="Nouvelle étiquette", ja="新しいラベル")
add("Delete label", zh_CN="删除标签", es="Eliminar etiqueta", fr="Supprimer l’étiquette", ja="ラベルを削除")

# --- Gap fill (config/sort/parent/C++ user-facing) ---
add("%1 grid units", zh_CN="%1 网格单位", es="%1 unidades de cuadrícula", fr="%1 unités de grille", ja="%1 グリッド単位")
add("%1:00", zh_CN="%1:00", es="%1:00", fr="%1:00", ja="%1:00")
add("1 day before", zh_CN="提前 1 天", es="1 día antes", fr="1 jour avant", ja="1日前")
add("1 hour", zh_CN="1 小时", es="1 hora", fr="1 heure", ja="1時間")
add("1 hour before", zh_CN="提前 1 小时", es="1 hora antes", fr="1 heure avant", ja="1時間前")
add("1 line", zh_CN="1 行", es="1 línea", fr="1 ligne", ja="1行")
add("15 minutes", zh_CN="15 分钟", es="15 minutos", fr="15 minutes", ja="15分")
add("15 minutes before", zh_CN="提前 15 分钟", es="15 minutos antes", fr="15 minutes avant", ja="15分前")
add("2 lines", zh_CN="2 行", es="2 líneas", fr="2 lignes", ja="2行")
add("A task cannot be its own parent.", zh_CN="任务不能作为自己的父任务。", es="Una tarea no puede ser su propio padre.", fr="Une tâche ne peut pas être son propre parent.", ja="タスクを自身の親にはできません。")
add("A task is due.", zh_CN="有任务到期。", es="Hay una tarea vencida.", fr="Une tâche est due.", ja="タスクの期限です。")
add("Add Kurrent task", zh_CN="添加 Kurrent 任务", es="Añadir tarea de Kurrent", fr="Ajouter une tâche Kurrent", ja="Kurrent タスクを追加")
add("Add label", zh_CN="添加标签", es="Añadir etiqueta", fr="Ajouter une étiquette", ja="ラベルを追加")
add("Afternoon", zh_CN="下午", es="Tarde", fr="Après-midi", ja="午後")
add("Afternoon starts", zh_CN="下午开始于", es="Inicio de la tarde", fr="Début de l’après-midi", ja="午後の開始")
add("Akonadi is not available.", zh_CN="Akonadi 不可用。", es="Akonadi no está disponible.", fr="Akonadi n’est pas disponible.", ja="Akonadi を利用できません。")
add("Akonadi is not running", zh_CN="Akonadi 未运行", es="Akonadi no está en ejecución", fr="Akonadi n’est pas lancé", ja="Akonadi が起動していません")
add("Connecting to Akonadi…",
    zh_CN="正在连接 Akonadi…", es="Conectando con Akonadi…", fr="Connexion à Akonadi…", ja="Akonadi に接続中…")
add("Loading tasks…",
    zh_CN="正在加载任务…", es="Cargando tareas…", fr="Chargement des tâches…", ja="タスクを読み込み中…")
add("The flyout is ready; tasks appear when the server answers.",
    zh_CN="弹出层已就绪；服务器响应后将显示任务。",
    es="El panel ya está listo; las tareas aparecen cuando responde el servidor.",
    fr="Le panneau est prêt ; les tâches apparaissent dès que le serveur répond.",
    ja="フライアウトは準備済みです。サーバー応答後にタスクが表示されます。")
add("Ask before deleting a task", zh_CN="删除任务前询问", es="Preguntar antes de eliminar una tarea", fr="Demander avant de supprimer une tâche", ja="タスク削除前に確認する")
add("At due time", zh_CN="截止时", es="A la hora de vencimiento", fr="À l’échéance", ja="期限時刻")
add("Background", zh_CN="背景", es="Fondo", fr="Arrière-plan", ja="背景")
add("Blurred wallpaper behind the widget", zh_CN="部件后方的模糊壁纸", es="Fondo de pantalla desenfocado detrás del widget", fr="Fond d’écran flou derrière le widget", ja="ウィジェット後ろのぼかした壁紙")
add("Cannot create a circular task hierarchy.", zh_CN="无法创建循环的任务层级。", es="No se puede crear una jerarquía circular de tareas.", fr="Impossible de créer une hiérarchie de tâches circulaire.", ja="循環するタスク階層は作れません。")
add("Case sensitive", zh_CN="区分大小写", es="Distinguir mayúsculas/minúsculas", fr="Sensible à la casse", ja="大文字小文字を区別")
add("Catch-up", zh_CN="补做", es="Ponerse al día", fr="Rattrapage", ja="キャッチアップ")
add("Checkbox", zh_CN="复选框", es="Casilla", fr="Case à cocher", ja="チェックボックス")
add("Click a task", zh_CN="点击任务", es="Clic en una tarea", fr="Clic sur une tâche", ja="タスクをクリック")
add("Collapse subtasks", zh_CN="折叠子任务", es="Contraer subtareas", fr="Replier les sous-tâches", ja="サブタスクを折りたたむ")
add("Comfortable", zh_CN="舒适", es="Cómodo", fr="Confortable", ja="ゆったり")
add("Complete only with Shift or Ctrl held", zh_CN="仅在按住 Shift 或 Ctrl 时完成", es="Completar solo con Mayús o Ctrl pulsadas", fr="Terminer seulement avec Maj ou Ctrl enfoncée", ja="Shift または Ctrl を押しながら完了")
add("Completing a parent also completes its children", zh_CN="完成父任务时也完成其子任务", es="Completar un padre también completa sus hijos", fr="Terminer une tâche parente termine aussi ses enfants", ja="親を完了すると子も完了する")
add("Configure CalDAV/Nextcloud in KOrganizer or Merkuro (DAV groupware resource).",    zh_CN="在 KOrganizer 或 Merkuro 中配置 CalDAV/Nextcloud（DAV 群件资源）。",
    es="Configura CalDAV/Nextcloud en KOrganizer o Merkuro (recurso DAV groupware).",
    fr="Configurez CalDAV/Nextcloud dans KOrganizer ou Merkuro (ressource DAV).",
    ja="KOrganizer または Merkuro で CalDAV/Nextcloud を設定してください（DAV グループウェアリソース）。")
add("Could not load tasks", zh_CN="无法加载任务", es="No se pudieron cargar las tareas", fr="Impossible de charger les tâches", ja="タスクを読み込めませんでした")
add("Counts", zh_CN="计数", es="Contadores", fr="Compteurs", ja="件数")
add("Dates", zh_CN="日期", es="Fechas", fr="Dates", ja="日付")
add("Default due date", zh_CN="默认截止日期", es="Fecha de vencimiento predeterminada", fr="Date d’échéance par défaut", ja="デフォルトの期限")
add("Default reminder", zh_CN="默认提醒", es="Recordatorio predeterminado", fr="Rappel par défaut", ja="デフォルトのリマインダー")
add("Delete", zh_CN="删除", es="Eliminar", fr="Supprimer", ja="削除")
add("Delete task?", zh_CN="删除任务？", es="¿Eliminar tarea?", fr="Supprimer la tâche ?", ja="タスクを削除しますか？")
add("Delete this task?", zh_CN="删除此任务？", es="¿Eliminar esta tarea?", fr="Supprimer cette tâche ?", ja="このタスクを削除しますか？")
add("Density", zh_CN="密度", es="Densidad", fr="Densité", ja="密度")
add("Description preview", zh_CN="描述预览", es="Vista previa de la descripción", fr="Aperçu de la description", ja="説明のプレビュー")
add("Desktop notifications", zh_CN="桌面通知", es="Notificaciones de escritorio", fr="Notifications de bureau", ja="デスクトップ通知")
add("Due %1", zh_CN="截止 %1", es="Vence %1", fr="Échéance %1", ja="期限 %1")
add("Due date (latest first)", zh_CN="截止日期（最新优先）", es="Fecha de vencimiento (más reciente primero)", fr="Date d’échéance (plus récente d’abord)", ja="期限（新しい順）")
add("Editor dim", zh_CN="编辑器遮罩", es="Oscurecimiento del editor", fr="Assombrissement de l’éditeur", ja="エディタの暗さ")
add("Enable a calendar in Configure Kurrent → Projects, or add a CalDAV resource in Merkuro or KOrganizer.",    zh_CN="在“配置 Kurrent → 项目”中启用日历，或在 Merkuro / KOrganizer 中添加 CalDAV 资源。",
    es="Activa un calendario en Configurar Kurrent → Proyectos, o añade un recurso CalDAV en Merkuro o KOrganizer.",
    fr="Activez un calendrier dans Configurer Kurrent → Projets, ou ajoutez une ressource CalDAV dans Merkuro ou KOrganizer.",
    ja="Kurrent の設定 → プロジェクトでカレンダーを有効にするか、Merkuro または KOrganizer で CalDAV リソースを追加してください。")
add("Ends", zh_CN="结束", es="Fin", fr="Fin", ja="終了")
add("Evening", zh_CN="晚上", es="Noche", fr="Soir", ja="夜")
add("Evening starts", zh_CN="晚上开始于", es="Inicio de la noche", fr="Début de la soirée", ja="夜の開始")
add("Exclude collapsed subtasks from counts", zh_CN="计数时排除已折叠的子任务", es="Excluir subtareas contraídas del recuento", fr="Exclure les sous-tâches repliées des compteurs", ja="折りたたんだサブタスクを件数から除外")
add("Expand subtasks", zh_CN="展开子任务", es="Expandir subtareas", fr="Déplier les sous-tâches", ja="サブタスクを展開")
add("Failed to fetch collections.", zh_CN="获取集合失败。", es="No se pudieron obtener las colecciones.", fr="Échec du chargement des collections.", ja="コレクションの取得に失敗しました。")
add("Flyout height", zh_CN="弹出高度", es="Alto del desplegable", fr="Hauteur du menu déroulant", ja="フライアウトの高さ")
add("Flyout width", zh_CN="弹出宽度", es="Ancho del desplegable", fr="Largeur du menu déroulant", ja="フライアウトの幅")
add("Heading on the list", zh_CN="列表中的标题", es="Encabezado en la lista", fr="Titre dans la liste", ja="リスト上の見出し")
add("Hidden", zh_CN="隐藏", es="Oculto", fr="Masqué", ja="非表示")
add("In 1 hour", zh_CN="1 小时后", es="En 1 hora", fr="Dans 1 heure", ja="1時間後")
add("In 15 minutes", zh_CN="15 分钟后", es="En 15 minutos", fr="Dans 15 minutes", ja="15分後")
add("In 4 hours", zh_CN="4 小时后", es="En 4 horas", fr="Dans 4 heures", ja="4時間後")
add("Light", zh_CN="浅", es="Ligero", fr="Léger", ja="弱い")
add("Manage which writable Akonadi calendars are used as projects. Disabled calendars are excluded from task fetching entirely. Hidden calendars are still fetched but not shown in the sidebar.",    zh_CN="管理哪些可写的 Akonadi 日历用作项目。禁用的日历完全不获取任务。隐藏的日历仍会获取，但不在侧栏显示。",
    es="Elige qué calendarios Akonadi escribibles se usan como proyectos. Los desactivados no se consultan. Los ocultos se consultan pero no aparecen en la barra lateral.",
    fr="Choisissez les calendriers Akonadi modifiables utilisés comme projets. Les calendriers désactivés sont exclus. Les calendriers masqués sont chargés mais absents de la barre latérale.",
    ja="プロジェクトとして使う書き込み可能な Akonadi カレンダーを管理します。無効なカレンダーはタスク取得から除外されます。非表示のカレンダーは取得されますが、サイドバーには表示されません。")
add("Meetings", zh_CN="会议", es="Reuniones", fr="Réunions", ja="会議")
add("Morning", zh_CN="上午", es="Mañana", fr="Matin", ja="午前")
add("Morning starts", zh_CN="上午开始于", es="Inicio de la mañana", fr="Début du matin", ja="午前の開始")
add("Motion", zh_CN="动画", es="Movimiento", fr="Mouvement", ja="モーション")
add("No task lists", zh_CN="没有任务列表", es="No hay listas de tareas", fr="Aucune liste de tâches", ja="タスクリストがありません")
add("No task lists found in Akonadi. Configure CalDAV in KOrganizer or Kalendar.",    zh_CN="在 Akonadi 中未找到任务列表。请在 KOrganizer 或 Kalendar 中配置 CalDAV。",
    es="No se encontraron listas de tareas en Akonadi. Configura CalDAV en KOrganizer o Kalendar.",
    fr="Aucune liste de tâches trouvée dans Akonadi. Configurez CalDAV dans KOrganizer ou Kalendar.",
    ja="Akonadi にタスクリストが見つかりません。KOrganizer または Kalendar で CalDAV を設定してください。")
add("No writable Akonadi calendars found. Make sure Akonadi is running and your CalDAV resource allows task edits.",    zh_CN="未找到可写的 Akonadi 日历。请确认 Akonadi 正在运行，且 CalDAV 资源允许编辑任务。",
    es="No se encontraron calendarios Akonadi escribibles. Comprueba que Akonadi esté en ejecución y que tu recurso CalDAV permita editar tareas.",
    fr="Aucun calendrier Akonadi modifiable trouvé. Vérifiez qu’Akonadi est lancé et que votre ressource CalDAV autorise l’édition des tâches.",
    ja="書き込み可能な Akonadi カレンダーが見つかりません。Akonadi が起動しており、CalDAV リソースがタスク編集を許可しているか確認してください。")
add("No writable task list selected.", zh_CN="未选择可写的任务列表。", es="No hay una lista de tareas escribible seleccionada.", fr="Aucune liste de tâches modifiable sélectionnée.", ja="書き込み可能なタスクリストが選択されていません。")
add("Notify when a task reminder is due", zh_CN="任务提醒到期时通知", es="Notificar cuando venza un recordatorio de tarea", fr="Notifier lorsqu’un rappel de tâche est dû", ja="タスクのリマインダーが来たら通知")
add("Off", zh_CN="关闭", es="Desactivado", fr="Désactivé", ja="オフ")
add("Open root tasks", zh_CN="未完成的根任务", es="Tareas raíz abiertas", fr="Tâches racines ouvertes", ja="未完了のルートタスク")
add("Open the full editor", zh_CN="打开完整编辑器", es="Abrir el editor completo", fr="Ouvrir l’éditeur complet", ja="フルエディタを開く")
add("Open the inline editor", zh_CN="打开行内编辑器", es="Abrir el editor en línea", fr="Ouvrir l’éditeur en ligne", ja="インライン編集を開く")
add("Order and visibility", zh_CN="顺序与可见性", es="Orden y visibilidad", fr="Ordre et visibilité", ja="順序と表示")
add("Panel badge", zh_CN="面板角标", es="Insignia del panel", fr="Badge du panneau", ja="パネルバッジ")
add("Parent task must be in the same project.", zh_CN="父任务必须在同一项目中。", es="La tarea padre debe estar en el mismo proyecto.", fr="La tâche parente doit être dans le même projet.", ja="親タスクは同じプロジェクト内である必要があります。")
add("Parent task not found.", zh_CN="未找到父任务。", es="Tarea padre no encontrada.", fr="Tâche parente introuvable.", ja="親タスクが見つかりません。")
add("Progress %", zh_CN="进度 %", es="Progreso %", fr="Progression %", ja="進捗 %")
add("Progress % (high first)", zh_CN="进度 %（高优先）", es="Progreso % (mayor primero)", fr="Progression % (plus élevée d’abord)", ja="進捗 %（高い順）")
add("Quiet hours", zh_CN="免打扰时段", es="Horas tranquilas", fr="Heures calmes", ja="おやすみ時間")
add("Recurring first", zh_CN="重复优先", es="Recurrentes primero", fr="Récurrentes d’abord", ja="繰り返し優先")
add("Recurring icon", zh_CN="重复图标", es="Icono de recurrencia", fr="Icône de récurrence", ja="繰り返しアイコン")
add("Recurring last", zh_CN="重复靠后", es="Recurrentes al final", fr="Récurrentes en dernier", ja="繰り返し最後")
add("Reduced motion (no spinner, quieter hover)", zh_CN="减少动效（无旋转指示、更安静的悬停）", es="Movimiento reducido (sin spinner, hover más suave)", fr="Mouvement réduit (pas de spinner, survol plus discret)", ja="動きを減らす（スピナーなし、ホバー控えめ）")
add("Relative dates (Today, Tomorrow)", zh_CN="相对日期（今天、明天）", es="Fechas relativas (Hoy, Mañana)", fr="Dates relatives (Aujourd’hui, Demain)", ja="相対日付（今日、明日）")
add("Remember the last view instead", zh_CN="改为记住上次视图", es="Recordar la última vista en su lugar", fr="Mémoriser la dernière vue à la place", ja="代わりに最後のビューを記憶")
add("Reminder first", zh_CN="提醒优先", es="Recordatorio primero", fr="Rappel d’abord", ja="リマインダー優先")
add("Reminder last", zh_CN="提醒靠后", es="Recordatorio al final", fr="Rappel en dernier", ja="リマインダー最後")
add("Reminder:", zh_CN="提醒：", es="Recordatorio:", fr="Rappel :", ja="リマインダー:")
add("Rename", zh_CN="重命名", es="Renombrar", fr="Renommer", ja="名前を変更")
add("Rename from", zh_CN="原名称", es="Renombrar de", fr="Renommer depuis", ja="変更元")
add("Rename to", zh_CN="新名称", es="Renombrar a", fr="Renommer en", ja="変更先")
add("Reset this page", zh_CN="重置此页", es="Restablecer esta página", fr="Réinitialiser cette page", ja="このページをリセット")
add("Row chips", zh_CN="行内芯片", es="Chips de fila", fr="Puces de ligne", ja="行のチップ")
add("Row size", zh_CN="行高", es="Tamaño de fila", fr="Taille des lignes", ja="行の高さ")
add("Search", zh_CN="搜索", es="Buscar", fr="Recherche", ja="検索")
add("Search titles only", zh_CN="仅搜索标题", es="Buscar solo en títulos", fr="Rechercher uniquement dans les titres", ja="タイトルのみ検索")
add("Section:", zh_CN="分区：", es="Sección:", fr="Section :", ja="セクション:")
add("Sections", zh_CN="分区", es="Secciones", fr="Sections", ja="セクション")
add("Select only (double-click opens the full editor)", zh_CN="仅选择（双击打开完整编辑器）", es="Solo seleccionar (doble clic abre el editor completo)", fr="Sélection seule (double-clic ouvre l’éditeur complet)", ja="選択のみ（ダブルクリックでフルエディタ）")
add("Show Kurrent", zh_CN="显示 Kurrent", es="Mostrar Kurrent", fr="Afficher Kurrent", ja="Kurrent を表示")
add("Show a Join button for http(s) links", zh_CN="为 http(s) 链接显示“加入”按钮", es="Mostrar un botón Unirse para enlaces http(s)", fr="Afficher un bouton Rejoindre pour les liens http(s)", ja="http(s) リンクに参加ボタンを表示")
add("Show empty projects", zh_CN="显示空项目", es="Mostrar proyectos vacíos", fr="Afficher les projets vides", ja="空のプロジェクトを表示")
add("Show in the sidebar", zh_CN="在侧栏中显示", es="Mostrar en la barra lateral", fr="Afficher dans la barre latérale", ja="サイドバーに表示")
add("Show task counts", zh_CN="显示任务数量", es="Mostrar recuento de tareas", fr="Afficher le nombre de tâches", ja="タスク数を表示")
add("Show time on the due chip", zh_CN="在截止日期芯片上显示时间", es="Mostrar la hora en el chip de vencimiento", fr="Afficher l’heure sur la puce d’échéance", ja="期限チップに時刻を表示")
add("Show overdue tasks at the top of Today", zh_CN="在“今天”顶部显示过期任务", es="Mostrar tareas vencidas al inicio de Hoy", fr="Afficher les tâches en retard en haut de Aujourd’hui", ja="期限切れのタスクを今日の先頭に表示")
add("Snooze from the notification (15 minutes, 1 hour, tomorrow) rewrites the VALARM. Due date is unchanged; use Reschedule for that.",    zh_CN="从通知推迟（15 分钟、1 小时、明天）会改写 VALARM。截止日期不变；改期请用“重新安排”。",
    es="Posponer desde la notificación (15 minutos, 1 hora, mañana) reescribe el VALARM. La fecha de vencimiento no cambia; usa Reprogramar para eso.",
    fr="Reporter depuis la notification (15 minutes, 1 heure, demain) réécrit le VALARM. La date d’échéance ne change pas ; utilisez Reporter pour cela.",
    ja="通知からのスヌーズ（15分、1時間、明日）は VALARM を書き換えます。期限は変わりません。期限変更にはリスケジュールを使います。")
add("Start date", zh_CN="开始日期", es="Fecha de inicio", fr="Date de début", ja="開始日")
add("Start it with akonadictl start, then add a CalDAV resource in Merkuro or KOrganizer.",    zh_CN="请用 akonadictl start 启动，然后在 Merkuro 或 KOrganizer 中添加 CalDAV 资源。",
    es="Inícialo con akonadictl start y luego añade un recurso CalDAV en Merkuro o KOrganizer.",
    fr="Démarrez-le avec akonadictl start, puis ajoutez une ressource CalDAV dans Merkuro ou KOrganizer.",
    ja="akonadictl start で起動し、Merkuro または KOrganizer で CalDAV リソースを追加してください。")
add("Starts", zh_CN="开始", es="Inicio", fr="Début", ja="開始")
add("Still open", zh_CN="仍未完成", es="Aún abiertas", fr="Encore ouvertes", ja="未完了のまま")
add("Strong", zh_CN="强", es="Fuerte", fr="Fort", ja="強い")
add("Subtasks", zh_CN="子任务", es="Subtareas", fr="Sous-tâches", ja="サブタスク")
add("Suppress reminder notifications in this window", zh_CN="在此时间段内抑制提醒通知", es="Suprimir notificaciones de recordatorio en este intervalo", fr="Supprimer les notifications de rappel dans cette plage", ja="この時間帯はリマインダー通知を抑制")
add("Task not found.", zh_CN="未找到任务。", es="Tarea no encontrada.", fr="Tâche introuvable.", ja="タスクが見つかりません。")
add("Task reminder", zh_CN="任务提醒", es="Recordatorio de tarea", fr="Rappel de tâche", ja="タスクのリマインダー")
add("The full editor stays an overlay inside the widget. Day section (LIST) is in the full editor.",    zh_CN="完整编辑器仍是部件内的覆盖层。日分区（LIST）在完整编辑器中。",
    es="El editor completo sigue siendo una superposición dentro del widget. La sección del día (LIST) está en el editor completo.",
    fr="L’éditeur complet reste une superposition dans le widget. La section du jour (LIST) est dans l’éditeur complet.",
    ja="フルエディタはウィジェット内のオーバーレイのままです。日セクション（LIST）はフルエディタにあります。")
add("This project cannot accept tasks.", zh_CN="此项目无法接受任务。", es="Este proyecto no puede aceptar tareas.", fr="Ce projet ne peut pas accepter de tâches.", ja="このプロジェクトにはタスクを追加できません。")
add("Try again", zh_CN="重试", es="Reintentar", fr="Réessayer", ja="再試行")
add("Undo", zh_CN="撤销", es="Deshacer", fr="Annuler", ja="元に戻す")
add("Undo complete", zh_CN="撤销完成", es="Deshacer completar", fr="Annuler la terminaison", ja="完了を取り消す")
add("Undo delete", zh_CN="撤销删除", es="Deshacer eliminación", fr="Annuler la suppression", ja="削除を取り消す")
add("Undo move", zh_CN="撤销移动", es="Deshacer movimiento", fr="Annuler le déplacement", ja="移動を取り消す")
add("Undo reschedule", zh_CN="撤销改期", es="Deshacer reprogramación", fr="Annuler le report", ja="スケジュール変更を取り消す")
add("Views", zh_CN="视图", es="Vistas", fr="Vues", ja="ビュー")
add("Width", zh_CN="宽度", es="Ancho", fr="Largeur", ja="幅")

PLURALS = {
    "%1 open task": {
        "msgid_plural": "%1 open tasks",
        "de": ["%1 offene Aufgabe", "%1 offene Aufgaben"],
        "es": ["%1 tarea abierta", "%1 tareas abiertas"],
        "fr": ["%1 tâche ouverte", "%1 tâches ouvertes"],
        "ja": ["%1 件の未完了タスク"],
        "zh_CN": ["%1 个未完成任务", "%1 个未完成任务"],
    },
    "%1 task": {
        "msgid_plural": "%1 tasks",
        "de": ["%1 Aufgabe", "%1 Aufgaben"],
        "es": ["%1 tarea", "%1 tareas"],
        "fr": ["%1 tâche", "%1 tâches"],
        "ja": ["%1 件のタスク"],
        "zh_CN": ["%1 个任务", "%1 个任务"],
    },
}

LANGS = {
    "de": ("de", "nplurals=2; plural=(n != 1);"),
    "es": ("es", "nplurals=2; plural=(n != 1);"),
    "fr": ("fr", "nplurals=2; plural=(n > 1);"),
    "ja": ("ja", "nplurals=1; plural=0;"),
    "zh_CN": ("zh_CN", "nplurals=1; plural=0;"),
}

LANG_NAMES = {
    "de": "German",
    "es": "Spanish",
    "fr": "French",
    "ja": "Japanese",
    "zh_CN": "Chinese (Simplified)",
}


def po_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def header(lang: str, plural: str) -> str:
    return f'''# Translation of {DOMAIN} to {LANG_NAMES[lang]}.
# Copyright (C) {YEAR} Kurrent Contributors
# This file is distributed under the same license as the kurrent package.
#
msgid ""
msgstr ""
"Project-Id-Version: kurrent 0.2.0\\n"
"Report-Msgid-Bugs-To: \\n"
"POT-Creation-Date: {YEAR}-01-01 00:00+0000\\n"
"PO-Revision-Date: {YEAR}-01-01 00:00+0000\\n"
"Last-Translator: Kurrent Contributors\\n"
"Language-Team: {LANG_NAMES[lang]}\\n"
"Language: {lang}\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: {plural}\\n"
'''


def main() -> None:
    out_dir = Path(__file__).resolve().parent
    missing: dict[str, list[str]] = {lang: [] for lang in LANGS}
    for lang, (_, plural) in LANGS.items():
        nplurals = 2
        if "nplurals=6" in plural:
            nplurals = 6
        elif "nplurals=3" in plural:
            nplurals = 3
        elif "nplurals=1" in plural:
            nplurals = 1
        body = [header(lang, plural), ""]
        extra = EXTRA.get(lang, {})
        for msgid, langs in STRINGS:
            msgstr = extra.get(msgid, langs.get(lang, msgid))
            if lang in EXTRA and msgid not in extra and lang not in langs:
                missing[lang].append(msgid)
            body.append(f'msgid "{po_escape(msgid)}"')
            body.append(f'msgstr "{po_escape(msgstr)}"')
            body.append("")
        for msgid, data in PLURALS.items():
            forms = list(data.get(lang, EXTRA_PLURALS.get(lang, [msgid])))
            while len(forms) < nplurals:
                forms.append(forms[-1])
            body.append(f'msgid "{po_escape(msgid)}"')
            body.append(f'msgid_plural "{po_escape(data["msgid_plural"])}"')
            for i in range(nplurals):
                body.append(f'msgstr[{i}] "{po_escape(forms[i])}"')
            body.append("")
        (out_dir / f"{lang}.po").write_text("\n".join(body), encoding="utf-8")
        print(f"Wrote {lang}.po")
    for lang, items in missing.items():
        if items:
            print(f"MISSING {lang}: {len(items)}")
            for item in items:
                print(f"  {item}")


if __name__ == "__main__":
    main()
