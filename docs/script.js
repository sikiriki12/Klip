// ===================================
// Klip Landing Page - JavaScript
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    initScrollReveal();
    initFAQ();
    initSmoothScroll();
    initNavScroll();
});

// ===================================
// Scroll Reveal Animations
// ===================================

function initScrollReveal() {
    const revealElements = document.querySelectorAll(
        '.section-header, .pipeline-step, .mode-card, .testimonial-card, ' +
        '.step-card, .hook-example, .language-pill, .context-content, .context-visual, ' +
        '.flow-step, .faq-item'
    );

    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                // Add staggered delay for grid items
                const delay = entry.target.dataset.delay || 0;
                setTimeout(() => {
                    entry.target.classList.add('reveal', 'active');
                }, delay);
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    revealElements.forEach((el, index) => {
        el.classList.add('reveal');
        // Stagger animations for sibling elements
        const parent = el.parentElement;
        const siblings = Array.from(parent.children).filter(child =>
            child.classList.contains('reveal') ||
            child.classList.contains('pipeline-step') ||
            child.classList.contains('mode-card') ||
            child.classList.contains('flow-step')
        );
        const siblingIndex = siblings.indexOf(el);
        el.dataset.delay = siblingIndex * 100;
        observer.observe(el);
    });
}

// ===================================
// FAQ Accordion
// ===================================

function initFAQ() {
    const faqItems = document.querySelectorAll('.faq-item');

    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');

        question.addEventListener('click', () => {
            const isActive = item.classList.contains('active');

            // Close all other FAQs
            faqItems.forEach(faq => {
                if (faq !== item) {
                    faq.classList.remove('active');
                }
            });

            // Toggle current FAQ
            item.classList.toggle('active', !isActive);
        });
    });
}

// ===================================
// Smooth Scroll for Anchor Links
// ===================================

function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));

            if (target) {
                const navHeight = document.querySelector('.nav').offsetHeight;
                const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navHeight - 20;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

// ===================================
// Navigation Scroll Effect
// ===================================

function initNavScroll() {
    const nav = document.querySelector('.nav');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;

        // Add shadow when scrolled
        if (currentScroll > 50) {
            nav.style.boxShadow = '0 4px 30px rgba(0, 0, 0, 0.3)';
        } else {
            nav.style.boxShadow = 'none';
        }

        lastScroll = currentScroll;
    });
}

// ===================================
// Typing Animation (Optional)
// ===================================

function typeText(element, text, speed = 50) {
    let index = 0;
    element.textContent = '';

    function type() {
        if (index < text.length) {
            element.textContent += text.charAt(index);
            index++;
            setTimeout(type, speed);
        }
    }

    type();
}

// ===================================
// Flow Demo Animation
// ===================================

function initFlowAnimation() {
    const flowSteps = document.querySelectorAll('.flow-step');
    const arrows = document.querySelectorAll('.flow-arrow');

    let currentStep = 0;

    function animateStep() {
        // Reset all steps
        flowSteps.forEach((step, index) => {
            step.style.opacity = index <= currentStep ? '1' : '0.3';
            step.style.transform = index === currentStep ? 'translateY(-4px)' : 'translateY(0)';
        });

        arrows.forEach((arrow, index) => {
            arrow.style.opacity = index < currentStep ? '1' : '0.3';
        });

        currentStep = (currentStep + 1) % (flowSteps.length + 1);

        if (currentStep === 0) {
            // Pause at the end before restarting
            setTimeout(animateStep, 2000);
        } else {
            setTimeout(animateStep, 1500);
        }
    }

    // Start animation when flow demo is visible
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateStep();
                observer.unobserve(entry.target);
            }
        });
    }, { threshold: 0.5 });

    const flowDemo = document.querySelector('.flow-demo');
    if (flowDemo) {
        observer.observe(flowDemo);
    }
}

// Initialize flow animation after a short delay
setTimeout(initFlowAnimation, 1000);
